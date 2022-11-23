;(function(){
    if (window.JSBridge){
        console.log("JSBridge exist!");
        return;
    }
    if (!window.onerror) {
        window.onerror = function(msg, url, line) {
            console.log("JSBridge ERROR:" + msg + "@" + url + ":" + line);
        }
    }
    
    window.JSBridge = {
        registerEventHandler : registerEventHandler,
        sendMessage : sendMessage,
        _setupPrepare: _setupPrepare,
        _onReceiveNativeReq : _onReceiveNativeReq,
        _onReceiveNativeResp : _onReceiveNativeResp,
        _onNativePrepared: _onNativePrepared,
    };
    
    var handlers = {};
    var resps = {};
    var messageQueues = [];
    var uniqueId = 1;
    var alertReqRespLog = true;// show log as alert
    var nativeReady = false
    let JSB_RESP_CODE_SUCC = '1'
    let JSB_RESP_CODE_FAILED = '0'
  
    function registerEventHandler(event, handler) {
        if (event && handler) {
            handlers[event] = handler;
        }
    }
  
    function sendMessage(event, data, onResp) {
        var callbackId = 'js_cb_'+(uniqueId++)
        var message = {
            '__event__':event,
            '__data__': (data ? data : {}),
            '__callbackId__':callbackId
        }

        __doSendMessage(message)
    }

    function __doSendMessage(message) {
    	if (!message) {
    		console.log('message required NOT null')
    		return
    	}

    	if (nativeReady) {
			console.log('__doSendMessage:' + message)
        	window.webkit.messageHandlers.JSBridgeReq.postMessage(message)
    	} else {
    		messageQueues.push(message)
    	}
    }
  
    function _setupPrepare() {
        var setupCallbacks = window.JSBSetupCallbacks
        if (!setupCallbacks) {
            return
        }
        delete window.JSBSetupCallbacks
        for (var i=0; i<setupCallbacks.length; i++) {
            setupCallbacks[i](JSBridge)
        }
        alertReqRespLog = true
    }

    function _flushMessageQueue() {
        console.log('not supported right now')
    }
  
    function _onReceiveNativeReq(message) {
        console.log("_onReceiveNativeReq: " + message)
        if (alertReqRespLog) {
            alert("_onReceiveNativeReq: " + message)
        }
        
        var messageJSON = JSON.parse(message)
        var event = messageJSON['__event__']
        var data = messageJSON['__data__']
        var callbackId = messageJSON['__callbackId__']
        
        // dispatch message
        if (event) {
            var handler = handlers[event]
            if (handler) {
                function response(respData) {
                    var resp = {}
                    if (callbackId) {
                        resp['__callbackId__'] = callbackId
                    }
                    if (respData) {
                        resp['__data__'] = respData
                    }
                    resp['__code__'] = JSB_RESP_CODE_SUCC
                    resp['__event__'] = event
  
                    _sendRespMessage(resp)
                }
  
                handler(event, data, response)
            }
        } else {
        	var resp = {}
            if (callbackId) {
                resp['__callbackId__'] = callbackId
            }
            resp['__data__'] = {}
            resp['__code__'] = JSB_RESP_CODE_FAILED
            resp['__event__'] = event

            _sendRespMessage(resp)
        }
    }
  
    function _sendRespMessage(payload) {
        console.log('_sendResp:')
        console.log(payload)
        window.webkit.messageHandlers.JSBridgeResp.postMessage(payload)
        console.log('after _sendResp')
    }
  
    function _onReceiveNativeResp(payload) {
        console.log("_onReceiveNativeResp: " + payload)
        if (alertReqRespLog) {
            alert("_onReceiveNativeResp: " + payload)
        }

        var messageJSON = JSON.parse(payload)
        var event = messageJSON['__event__']
        var data = messageJSON['__data__']
        var cbid = messageJSON['__callbackId__']
        if (cbid) {
            var callback = resps[cbid]
            if (callback) {
                callback(data)
                delete resps[cbid];
            }
        }
    }

    function _onNativePrepared() {
        if (nativeReady) {
            return
        }
    	nativeReady = true
    	__flushMessageQueue()
    }

    function __flushMessageQueue() {
        if (!!messageQueues && messageQueues.length > 0) {
            for (var i = 0; i < messageQueues.length; i++) {
                var msg = messageQueues[i]
                __doSendMessage(msg)
            }

            messageQueues.splice(0, messageQueues.length);
        }
    }
})();
