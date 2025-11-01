const isIOS=/iPad|iPhone|iPod/.test(navigator.userAgent);
const SR=window.SpeechRecognition||window.webkitSpeechRecognition;

const Bitacora={
  speechSupported:!!SR && !isIOS,
  _rec:null,_recording:false,

  async getLocation(){
    if(!("geolocation" in navigator)) throw new Error("GPS no disponible");
    return new Promise((resolve,reject)=>{
      navigator.geolocation.getCurrentPosition(
        pos=>{
          const {latitude,longitude,accuracy}=pos.coords;
          resolve({lat:+latitude.toFixed(6),lon:+longitude.toFixed(6),accuracy:Math.round(accuracy||0)});
        },
        err=>reject(err),
        {enableHighAccuracy:true,timeout:10000,maximumAge:0}
      );
    });
  },

  startSpeech(lang="es-AR"){
    if(!this.speechSupported) throw new Error("Speech no soportado");
    if(!this._rec){
      this._rec=new SR();
      this._rec.lang=lang; this._rec.interimResults=true; this._rec.continuous=true;
      this._rec.onresult=(e)=>{
        let finalText="";
        for(let i=e.resultIndex;i<e.results.length;i++){
          const r=e.results[i]; if(r.isFinal) finalText+=r[0].transcript;
        }
        finalText=finalText.trim();
        if(finalText){
          window.dispatchEvent(new CustomEvent("bitacora:speech",{detail:{text:finalText}}));
          try{ navigator.clipboard.writeText(finalText); }catch(_){}
        }
      };
      this._rec.onerror=(e)=>window.dispatchEvent(new CustomEvent("bitacora:speechError",{detail:e.error}));
      this._rec.onend=()=>{ if(this._recording) try{ this._rec.start(); }catch(_){} };
    }
    try{ this._rec.start(); this._recording=true; }catch(_){}
  },
  stopSpeech(){ this._recording=false; try{ this._rec&&this._rec.stop(); }catch(_){} },
  toggleSpeech(){ this._recording?this.stopSpeech():this.startSpeech(); },
  async copy(text){ try{ await navigator.clipboard.writeText(text); }catch(_){} }
};

window.Bitacora=Bitacora;

const gpsFab=document.getElementById("gpsFab");
const micFab=document.getElementById("micFab");

function toast(msg,ms=1800){
  const t=document.createElement("div"); t.className="toast"; t.textContent=msg;
  document.body.appendChild(t); setTimeout(()=>t.remove(),ms);
}

if(gpsFab){
  gpsFab.addEventListener("click",async()=>{
    try{
      toast("Obteniendo ubicación…",1200);
      const {lat,lon,accuracy}=await Bitacora.getLocation();
      const payload={lat,lon,accuracy,text:`${lat}, ${lon} \u00B1${accuracy} m`};
      window.dispatchEvent(new CustomEvent("bitacora:gps",{detail:payload}));
      await Bitacora.copy(payload.text);
      toast("Ubicación lista y copiada");
    }catch(e){ toast("No se pudo obtener la ubicación"); }
  });
}

if(micFab){
  if(!Bitacora.speechSupported){
    micFab.setAttribute("disabled","true");
    micFab.title="Dictado web no soportado en iPhone. Usá el mic del teclado.";
  }
  micFab.addEventListener("click",()=>{
    if(!Bitacora.speechSupported) return;
    Bitacora.toggleSpeech();
    micFab.classList.toggle("is-recording");
    toast(micFab.classList.contains("is-recording")?"Grabando…":"Dictado detenido",1200);
  });
}
