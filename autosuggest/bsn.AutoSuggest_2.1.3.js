/**
 *  author:		Timothy Groves - http://www.brandspankingnew.net
 *	version:	1.2 - 2006-11-17
 *              1.3 - 2006-12-04
 *              2.0 - 2007-02-07
 *              2.1.1 - 2007-04-13
 *              2.1.2 - 2007-07-07
 *              2.1.3 - 2007-07-19
 *
 */


/*if(typeof (bsn)=="undefined") {*/
    _b=bsn= {};
/*}*/

if(typeof (_b.Autosuggest)=="undefined") {
    _b.Autosuggest= {};
}
else {
    alert("Autosuggest is already set!");
}

_b.AutoSuggest=function(id,_2) {
    if(!document.getElementById) {
        return 0;
    }
    this.fld=_b.DOM.gE(id);
    if(!this.fld) {
        return 0;
    }
    this.sInp="";
    this.nInpC=0;
    this.aSug=[];
    this.iHigh=0;
    this.onFocusEvent=false;
    this.oP=_2?_2: {};
    var _3= {
        minchars:1, meth:"get", varname:"input", className:"autosuggest", timeout:2500, delay:1, offsety:-5,
        shownoresults:true, noresults:"No results!", maxheight:250, cache:true, onfocus:false, fillsingle:false,
        maxresults:10
    };
    for(k in _3) {
        if(typeof (this.oP[k])!=typeof (_3[k])) {
            this.oP[k]=_3[k];
        }
    }
    var p=this;
    this.fld.onkeypress=function(ev) {
        return p.onKeyPress(ev);
    };
    this.fld.onkeyup=function(ev) {
        return p.onKeyUp(ev);
    };
    this.fld.onblur=function() {
        p.onBlur();
    };
    if(this.oP.onfocus) {
        this.fld.onfocus=function() {
            p.onFocus();
        };
    }
    this.fld.setAttribute("autocomplete","off");
};

_b.AutoSuggest.prototype.onKeyPress=function(ev) {
    var _8=(window.event)?window.event.keyCode:ev.keyCode;
    var _9=13;
    var _a=9;
    var _b=27;
    var _c=1;
    switch(_8) {
    case _9:this.setHighlightedValue();
    _c=0;
    break;
    case _a:this.setHighlightedValue();
    this.clearHighlight();
    break;
    case _b:this.clearSuggestions();
    break;
    }
    return _c;
};

_b.AutoSuggest.prototype.onKeyUp=function(ev) {
    var _e=(window.event)?window.event.keyCode:ev.keyCode;
    var _f=38;
    var _10=40;
    var _11=1;
    switch(_e) {
    case _f:this.changeHighlight(_e);
    _11=0;
    break;
    case _10:this.changeHighlight(_e);
    _11=0;
    break;
    default:this.getSuggestions(this.fld.value);
    }
    return _11;
};

_b.AutoSuggest.prototype.onFocus=function() {
    this.onFocusEvent=true;
    this.getSuggestions(this.fld.value);
};

_b.AutoSuggest.prototype.onBlur=function() {
    this.clearSuggestions();
    this.onFocusEvent=false;
};

_b.AutoSuggest.prototype.getSuggestions=function(val) {
    if(
       ( !this.oP.onfocus && val==this.sInp )
       || ( val!="" && val==this.sInp )
    ) {
        this.onFocusEvent=false;
        return 0;
    }
    
    if(val.length<this.oP.minchars) {
        this.sInp="";
        this.onFocusEvent=false;
        return 0;
    }
    
    if( val.length>this.nInpC && this.aSug.length && this.oP.cache ) {
        var arr=[];
        for( var i=0; i<this.aSug.length; i++) {
            if( this.aSug[i].value.toLowerCase().indexOf(val.toLowerCase())!=-1 ) {
                arr.push(this.aSug[i]);
            }
        }
        this.sInp=val;
        this.nInpC=val.length;
        this.aSug=arr;
        this.createList(this.aSug);
        return false;
    }
    else {
        this.sInp=val;
        this.nInpC=val.length;
        var _15=this;
        clearTimeout(this.ajID);
        this.ajID=setTimeout(
            function() {
                _15.doAjaxRequest();
            },
            this.oP.delay
        );
    }
    return false;
};

_b.AutoSuggest.prototype.doAjaxRequest=function() {
    var _16=this;
    
    if(typeof (this.oP.script)=="function") {
        var url=this.oP.script(encodeURIComponent(this.fld.value));
    }
    else {
        var url=this.oP.script+this.oP.varname+"="+encodeURIComponent(this.fld.value);
    }
    
    if(!url) {
        return false;
    }
    
    var _19=this.oP.meth;
    var _1a=function(req) {
        _16.setSuggestions(req);
    };
    var _1c=function(_1d) {
        alert("AJAX error: "+_1d);
    };
    var _1e=new _b.Ajax();
    
    _1e.makeRequest(url,_19,_1a,_1c);
};

_b.AutoSuggest.prototype.setSuggestions=function(req) {
    this.aSug=[];
    if(this.oP.json) {
        var _20=eval("("+req.responseText+")");
        for(var i=0; i<_20.results.length; i++) {
            this.aSug.push( {
                "id":_20.results[i].id,"value":_20.results[i].value,"info":_20.results[i].info}
            );
        }
    }
    else {
        var xml=req.responseXML;
        var _23=xml.getElementsByTagName("results")[0].childNodes;
        for(var i=0; i<_23.length; i++) {
            if(_23[i].hasChildNodes()) {
                this.aSug.push( {
                    "id":_23[i].getAttribute("id"),"value":_23[i].childNodes[0].nodeValue,"info":_23[i].getAttribute("info")}
                );
            }
        }
    }
    this.idAs="as_"+this.fld.id;
    this.createList(this.aSug);
};

_b.AutoSuggest.prototype.createList=function(arr) {
    var _26=this;
    _b.DOM.remE(this.idAs);
    this.killTimeout();
    if(arr.length==0&&!this.oP.shownoresults) {
        return false;
    }
    if(this.oP.fillsingle&&this.onFocusEvent&&this.sInp==""&&arr.length==1) {
        this.setValue(1);
    }
    else {
        var div=_b.DOM.cE("div", {id:this.idAs,className:this.oP.className} );
        var _28=_b.DOM.cE("div", {className:"as_corner"} );
        var _29=_b.DOM.cE("div", {className:"as_bar"} );
        var _2a=_b.DOM.cE("div", {className:"as_header"} );
        _2a.appendChild(_28);
        _2a.appendChild(_29);
        div.appendChild(_2a);
        var ul=_b.DOM.cE("ul", {id:"as_ul"} );
        var _2c=this.oP.maxresults<arr.length?this.oP.maxresults:arr.length;
        for(var i=0; i<_2c; i++) {
            var val=arr[i].value + '';
            var st=val.toLowerCase().indexOf(this.sInp.toLowerCase());
            var _30=val.substring(0,st)+"<em>"+val.substring(st,st+this.sInp.length)+"</em>"+val.substring(st+this.sInp.length);
            var _31=_b.DOM.cE("span", {} ,_30,true);
            if(arr[i].info!="") {
                var br=_b.DOM.cE("br", {} );
                _31.appendChild(br);
                var _33=_b.DOM.cE("small", {},arr[i].info);
                _31.appendChild(_33);
            }
            var a=_b.DOM.cE("a", {href:"#"}       );
            var tl=_b.DOM.cE("span", {className:"tl"}        ," ");
            var tr=_b.DOM.cE("span", {className:"tr"}       ," ");
            a.appendChild(tl);
            a.appendChild(tr);
            a.appendChild(_31);
            a.name=i+1;
            a.onclick=function() {
                _26.setHighlightedValue();
                return false;
            };
            a.onmouseover=function() {
                _26.setHighlight(this.name);
            };
            var li=_b.DOM.cE("li", {},a);
            ul.appendChild(li);
        }
        if(arr.length==0&&this.oP.shownoresults) {
            var li=_b.DOM.cE("li", {className:"as_warning"},this.oP.noresults);
            ul.appendChild(li);
        }
        div.appendChild(ul);
        var _39=_b.DOM.cE("div", {className:"as_corner"}        );
        var _3a=_b.DOM.cE("div", {className:"as_bar"}        );
        var _3b=_b.DOM.cE("div", {className:"as_footer"}        );
        _3b.appendChild(_39);
        _3b.appendChild(_3a);
        div.appendChild(_3b);
        var pos=_b.DOM.getPos(this.fld);
        div.style.left=pos.x+"px";
        div.style.top=(pos.y+this.fld.offsetHeight+this.oP.offsety)+"px";
        div.style.width=this.fld.offsetWidth+"px";
        div.onmouseover=function() {
            _26.killTimeout();
        };
        div.onmouseout=function() {
            _26.resetTimeout();
        };
        document.getElementsByTagName("body")[0].appendChild(div);
        this.iHigh=0;
        var _3d=this;
        this.toID=setTimeout(
            function() { _3d.clearSuggestions(); },
            this.oP.timeout
        );
    }
    this.onFocusEvent=false;
};

_b.AutoSuggest.prototype.changeHighlight=function(key) {
    var _3f=_b.DOM.gE("as_ul");
    if(!_3f) {
    return false;
    }
    var n;
    if(key==40) {
    n=this.iHigh+1;
    }
    else {
    if(key==38) {
    n=this.iHigh-1;
    }
    }
    if(n>_3f.childNodes.length) {
    n=_3f.childNodes.length;
    }
    if(n<1) {
    n=1;
    }
    this.setHighlight(n);
};

_b.AutoSuggest.prototype.setHighlight=function(n) {
    var _42=_b.DOM.gE("as_ul");
    if(!_42) {
    return false;
    }
    if(this.iHigh>0) {
    this.clearHighlight();
    }
    this.iHigh=Number(n);
    _42.childNodes[this.iHigh-1].className="as_highlight";
    this.killTimeout();
};

_b.AutoSuggest.prototype.clearHighlight=function() {
    var _43=_b.DOM.gE("as_ul");
    if(!_43) {
    return false;
    }
    if(this.iHigh>0) {
    _43.childNodes[this.iHigh-1].className="";
    this.iHigh=0;
    }
};

_b.AutoSuggest.prototype.setHighlightedValue=function() {
    if(this.iHigh) {
    this.sInp=this.fld.value=this.aSug[this.iHigh-1].value + '';
    this.fld.focus();
    if(this.fld.selectionStart) {
    this.fld.setSelectionRange(this.sInp.length,this.sInp.length);
    }
    this.clearSuggestions();
    if(typeof (this.oP.callback)=="function") {
    this.oP.callback(this.aSug[this.iHigh-1]);
    }
    }
};

_b.AutoSuggest.prototype.setValue=function(n) {
    this.sInp=this.fld.value=this.aSug[n-1].value + '';
    this.fld.focus();
    if(this.fld.selectionStart) {
    this.fld.setSelectionRange(0,this.sInp.length);
    }
    this.clearSuggestions();
    if(typeof (this.oP.callback)=="function") {
    this.oP.callback(this.aSug[n-1]);
    }
};

_b.AutoSuggest.prototype.killTimeout=function() {
clearTimeout(this.toID);
};

_b.AutoSuggest.prototype.resetTimeout=function() {
    clearTimeout(this.toID);
    var _45=this;
    this.toID=setTimeout(function() {
    _45.clearSuggestions();
    }
    ,1000);
};

_b.AutoSuggest.prototype.clearSuggestions=function() {
    this.killTimeout();
    var ele=_b.DOM.gE(this.idAs);
    var _47=this;
    if(ele) {
    var _48=new _b.Fader(ele,1,0,250,function() {
    _b.DOM.remE(_47.idAs);
    }
    );
    }
};

if(typeof (_b.Ajax)=="undefined") {
    _b.Ajax= {};
}

_b.Ajax=function() {
    this.req= {};
    this.isIE=false;
};

_b.Ajax.prototype.makeRequest=function(url,_4a,_4b,_4c) {
    if(_4a!="POST") {
        _4a="GET";
    }
    this.onComplete=_4b;
    this.onError=_4c;
    var _4d=this;
    if(window.XMLHttpRequest) {
        this.req=new XMLHttpRequest();
        this.req.onreadystatechange=function() {
            _4d.processReqChange();
        };
        this.req.open("GET",url,true);
        this.req.send(null);
    }
    else {
        if(window.ActiveXObject) {
            this.req=new ActiveXObject("Microsoft.XMLHTTP");
            if(this.req) {
                this.req.onreadystatechange=function() {
                    _4d.processReqChange();
                };
                this.req.open(_4a,url,true);
                this.req.send();
            }
        }
    }
};

_b.Ajax.prototype.processReqChange=function() {
    if(this.req.readyState==4) {
        if(this.req.status==200) {
            this.onComplete(this.req);
        }
        else {
            this.onError(this.req.status);
        }
    }
};

if(typeof (_b.DOM)=="undefined") {
    _b.DOM= {};
}

_b.DOM.cE=function(_4e,_4f,_50,_51) {
    var ne=document.createElement(_4e);
    if(!ne) {
    return 0;
    }
    for(var a in _4f) {
    ne[a]=_4f[a];
    }
    var t=typeof (_50);
    if(t=="string"&&!_51) {
    ne.appendChild(document.createTextNode(_50));
    }
    else {
    if(t=="string"&&_51) {
    ne.innerHTML=_50;
    }
    else {
    if(t=="object") {
    ne.appendChild(_50);
    }
    }
    }
    return ne;
};

_b.DOM.gE=function(e) {
    var t=typeof (e);
    if(t=="undefined") {
    return 0;
    }
    else {
    if(t=="string") {
    var re=document.getElementById(e);
    if(!re) {
    return 0;
    }
    else {
    if(typeof (re.appendChild)!="undefined") {
    return re;
    }
    else {
    return 0;
    }
    }
    }
    else {
    if(typeof (e.appendChild)!="undefined") {
    return e;
    }
    else {
    return 0;
    }
    }
    }
};

_b.DOM.remE=function(ele) {
    var e=this.gE(ele);
    if(!e) {
    return 0;
    }
    else {
    if(e.parentNode.removeChild(e)) {
    return true;
    }
    else {
    return 0;
    }
    }
};

_b.DOM.getPos=function(e) {
    var e=this.gE(e);
    var obj=e;
    var _5d=0;
    if(obj.offsetParent) {
    while(obj.offsetParent) {
    _5d+=obj.offsetLeft;
    obj=obj.offsetParent;
    }
    }
    else {
    if(obj.x) {
    _5d+=obj.x;
    }
    }
    var obj=e;
    var _5f=0;
    if(obj.offsetParent) {
    while(obj.offsetParent) {
    _5f+=obj.offsetTop;
    obj=obj.offsetParent;
    }
    }
    else {
    if(obj.y) {
    _5f+=obj.y;
    }
    }
    return  {
    x:_5d,y:_5f};
};

if(typeof (_b.Fader)=="undefined") {
    _b.Fader= {};
}

_b.Fader=function(ele,_61,to,_63,_64) {
    if(!ele) {
    return 0;
    }
    this.e=ele;
    this.from=_61;
    this.to=to;
    this.cb=_64;
    this.nDur=_63;
    this.nInt=50;
    this.nTime=0;
    var p=this;
    this.nID=setInterval(function() {
    p._fade();
    }
    ,this.nInt);
};

_b.Fader.prototype._fade=function() {
    this.nTime+=this.nInt;
    var _66=Math.round(this._tween(this.nTime,this.from,this.to,this.nDur)*100);
    var op=_66/100;
    if(this.e.filters) {
    try {
    this.e.filters.item("DXImageTransform.Microsoft.Alpha").opacity=_66;
    }
    catch(e) {
    this.e.style.filter="progid:DXImageTransform.Microsoft.Alpha(opacity="+_66+")";
    }
    }
    else {
    this.e.style.opacity=op;
    }
    if(this.nTime==this.nDur) {
    clearInterval(this.nID);
    if(this.cb!=undefined) {
    this.cb();
    }
    }
};

_b.Fader.prototype._tween=function(t,b,c,d) {
    return b+((c-b)*(t/d));
};
