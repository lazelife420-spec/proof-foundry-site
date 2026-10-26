'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process');
function seal(artifact){
  const root=path.resolve(__dirname,'..'),output=path.resolve(artifact)+'-functions';
  assert.equal(fs.existsSync(output),false,'Fresh independent function build required');
  const cli=path.join(root,'node_modules/wrangler/bin/wrangler.js');
  assert.equal(JSON.parse(fs.readFileSync(path.join(root,'node_modules/wrangler/package.json'))).version,'4.105.0');
  const r=spawnSync(process.execPath,[cli,'pages','functions','build',path.join(root,'functions'),'--outdir',output,'--output-routes-path',path.join(artifact,'_routes.json'),'--minify','--compatibility-date','2026-06-30'],{cwd:root,encoding:'utf8',windowsHide:true,maxBuffer:8*1024*1024});
  process.stdout.write(r.stdout||'');process.stderr.write(r.stderr||'');assert.equal(r.status,0,'Pages function compilation failed');
  assert.deepEqual(fs.readdirSync(output),['index.js'],'Unexpected function modules');
  const bytes=fs.readFileSync(path.join(output,'index.js'));
  assert.ok(bytes.toString().includes('export'),'ES module output required');assert.ok(!bytes.toString().startsWith('------'),'Multipart upload envelope is not Worker source');
  fs.writeFileSync(path.join(artifact,'_worker.js'),bytes);
}
if(require.main===module){try{seal(path.resolve(process.argv[2]));}catch(error){console.error(error.message);process.exitCode=2;}}
module.exports={seal};
