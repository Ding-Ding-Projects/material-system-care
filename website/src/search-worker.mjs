self.onmessage = ({data}) => {
  try { const rx = new RegExp(data.pattern, data.flags); self.postMessage({matches:data.texts.map((text,index) => rx.test(text) ? index : -1).filter(index => index >= 0)}); }
  catch { self.postMessage({error:true}); }
};
