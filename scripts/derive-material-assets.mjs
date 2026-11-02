import {spawn} from 'node:child_process';
import {mkdtemp,readFile,writeFile,rm} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import os from 'node:os';import path from 'node:path';
// Derives web material assets from local source images (see MATERIAL_PROVENANCE.md).
// usage: node derive-material-assets.mjs <jobs.json>   jobs: [{src,out,crop:{x,y,w,h},mirrorX,mirrorY,scale,quality}]
//        node derive-material-assets.mjs --probe-rows <image>
// mirrorX/mirrorY append a reflected copy so the tile repeats without an edge discontinuity.
// Encoded with Chrome's canvas WebP encoder (headless, isolated profile).
const args=process.argv.slice(2);
const probe=args[0]==='--probe-rows';
const jobs=probe?[{src:args[1]}]:JSON.parse(await readFile(args[0],'utf8'));
const profile=await mkdtemp(path.join(os.tmpdir(),'pf-derive-'));
const chrome=spawn('C:/Program Files/Google/Chrome/Application/chrome.exe',['--headless=new','--remote-debugging-port=0','--user-data-dir='+profile,'--no-first-run','about:blank'],{stdio:'ignore'});
const pause=ms=>new Promise(r=>setTimeout(r,ms));
let port;for(let i=0;i<100&&!port;i++){try{port=(await readFile(path.join(profile,'DevToolsActivePort'),'utf8')).split(/\r?\n/)[0]}catch{await pause(100)}}
const tabs=await fetch('http://127.0.0.1:'+port+'/json/list').then(r=>r.json());
const ws=new WebSocket(tabs.find(t=>t.type==='page').webSocketDebuggerUrl);await new Promise((r,j)=>{ws.onopen=r;ws.onerror=j});
let id=0;const pending=new Map();ws.onmessage=e=>{const m=JSON.parse(e.data),p=pending.get(m.id);if(p){pending.delete(m.id);m.error?p.j(Error(m.error.message)):p.r(m.result)}};
const send=(method,params={})=>new Promise((r,j)=>{const i=++id;pending.set(i,{r,j});ws.send(JSON.stringify({id:i,method,params}))});
const sha=b=>createHash('sha256').update(b).digest('hex');
const results=[];
try{
for(const job of jobs){
 const bytes=await readFile(job.src),mime=job.src.endsWith('.png')?'image/png':'image/webp';
 const expr=`(async()=>{const img=new Image();img.src='data:${mime};base64,${bytes.toString('base64')}';await img.decode();
 const W=img.naturalWidth,H=img.naturalHeight,job=${JSON.stringify(job)};
 if(${probe}){const c=new OffscreenCanvas(W,H),x=c.getContext('2d');x.drawImage(img,0,0);const d=x.getImageData(0,0,W,H).data;const rows=[];for(let y=0;y<H;y+=12){let s=0;for(let k=y;k<Math.min(H,y+12);k++)for(let X=0;X<W;X+=3){const i=(k*W+X)*4;s+=d[i]*.2126+d[i+1]*.7152+d[i+2]*.0722}rows.push([y,Math.round(s/(12*Math.ceil(W/3)))])}return {W,H,rows}}
 const cr=job.crop||{x:0,y:0,w:W,h:H},nx=job.mirrorX?2:1,ny=job.mirrorY?2:1,s=job.scale||1;
 const tw=Math.round(cr.w*s),th=Math.round(cr.h*s),c=new OffscreenCanvas(tw*nx,th*ny),x=c.getContext('2d');x.imageSmoothingQuality='high';
 for(let i=0;i<nx;i++)for(let j=0;j<ny;j++){x.save();x.translate(i?tw*2:0,j?th*2:0);x.scale(i?-1:1,j?-1:1);x.drawImage(img,cr.x,cr.y,cr.w,cr.h,0,0,tw,th);x.restore()}
 const b=await c.convertToBlob({type:'image/webp',quality:job.quality||.8});const a=new Uint8Array(await b.arrayBuffer());let str='';for(let i=0;i<a.length;i+=32768)str+=String.fromCharCode(...a.subarray(i,i+32768));return {width:tw*nx,height:th*ny,b64:btoa(str)}})()`;
 const r=await send('Runtime.evaluate',{expression:expr,awaitPromise:true,returnByValue:true});
 if(r.exceptionDetails)throw Error(JSON.stringify(r.exceptionDetails));
 const v=r.result.value;
 if(probe){console.log(JSON.stringify(v));continue}
 const out=Buffer.from(v.b64,'base64');await writeFile(job.out,out);
 results.push({out:path.basename(job.out),source:path.basename(job.src),sourceSha256:sha(bytes),crop:job.crop,mirrorX:!!job.mirrorX,mirrorY:!!job.mirrorY,scale:job.scale||1,quality:job.quality||.8,width:v.width,height:v.height,bytes:out.length,sha256:sha(out)});
}
}finally{await send('Browser.close').catch(()=>{});await pause(300);chrome.kill();await rm(profile,{recursive:true,force:true}).catch(()=>{})}
if(!probe)console.log(JSON.stringify(results,null,1));
