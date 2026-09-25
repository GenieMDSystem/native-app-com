import Foundation

enum WebViewUserScripts {
    /// Mirrors Android `NativeApp.callback(json)`.
    static let nativeAppBridge = """
    (function() {
      if (window.NativeApp && window.NativeApp.callback) { return; }
      window.NativeApp = {
        callback: function(json) {
          try {
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.NativeApp) {
              window.webkit.messageHandlers.NativeApp.postMessage(String(json));
            }
          } catch (e) {
            console.warn('NativeApp.callback failed', e);
          }
        }
      };
    })();
    """

    /// Intercepts `<input type="file">` so WKWebView never presents its own Photos picker.
    /// That built-in picker is what freezes the page after dismiss (especially with Limited Photos access).
    static let fileInputIntercept = """
    (function() {
      if (window.__nativeFilePickerInstalled) { return; }
      window.__nativeFilePickerInstalled = true;
      var activeInput = null;

      function isFileInput(el) {
        return el && el.tagName === 'INPUT' && String(el.type || '').toLowerCase() === 'file';
      }

      document.addEventListener('click', function(e) {
        var el = e.target;
        if (!isFileInput(el) && el && el.closest) {
          el = el.closest('input[type="file"]');
        }
        if (!isFileInput(el)) { return; }
        e.preventDefault();
        e.stopPropagation();
        if (e.stopImmediatePropagation) { e.stopImmediatePropagation(); }
        activeInput = el;
        try {
          window.webkit.messageHandlers.NativeFilePicker.postMessage({
            accept: el.accept || '',
            multiple: !!el.multiple,
            capture: el.getAttribute('capture') || ''
          });
        } catch (err) {
          console.warn('NativeFilePicker post failed', err);
        }
      }, true);

      window.__nativeFilePickerDeliver = function(payload) {
        var input = activeInput;
        activeInput = null;
        if (!input) { return; }
        if (!payload || payload.cancelled) {
          try { input.dispatchEvent(new Event('cancel', { bubbles: true })); } catch (e) {}
          return;
        }
        try {
          var files = payload.files || [];
          var dt = new DataTransfer();
          for (var i = 0; i < files.length; i++) {
            var item = files[i];
            var byteChars = atob(item.base64);
            var bytes = new Uint8Array(byteChars.length);
            for (var b = 0; b < byteChars.length; b++) { bytes[b] = byteChars.charCodeAt(b); }
            var type = item.mime || 'application/octet-stream';
            var blob = new Blob([bytes], { type: type });
            dt.items.add(new File([blob], item.name || ('file-' + i), { type: type }));
          }
          input.files = dt.files;
          input.dispatchEvent(new Event('change', { bubbles: true }));
          input.dispatchEvent(new Event('input', { bubbles: true }));
        } catch (err) {
          console.error('Native file deliver failed', err);
          try { input.dispatchEvent(new Event('cancel', { bubbles: true })); } catch (e2) {}
        }
      };
    })();
    """
}
