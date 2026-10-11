import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { resolve, extname } from 'node:path';
import { fileURLToPath } from 'node:url';
const root=fileURLToPath(new URL('./dist/',import.meta.url));
const types={'.html':'text/html; charset=utf-8','.png':'image/png','.svg':'image/svg+xml','.css':'text/css; charset=utf-8','.js':'text/javascript; charset=utf-8'};
const limits=new Map();
const cookie=(req)=>{const raw=(req.headers.cookie||'').split(';').find(x=>x.trim().startsWith('qize_session='));return raw?raw.trim().slice('qize_session='.length):'';};
function json(res,status,data,headers={}){res.writeHead(status,{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store',...headers});res.end(JSON.stringify(data));}
async function rpc(name,args){const url=process.env.QIZE_SUPABASE_URL,key=process.env.QIZE_SUPABASE_KEY;if(!url||!key)throw new Error('DATABASE_NOT_CONFIGURED');const res=await fetch(url+'/rest/v1/rpc/qize_'+name,{method:'POST',headers:{apikey:key,'Content-Type':'application/json'},body:JSON.stringify(args),signal:AbortSignal.timeout(12000)});if(!res.ok)throw new Error('DATABASE_UNAVAILABLE');return res.json();}
async function body(req){let text='';for await(const chunk of req){text+=chunk;if(Buffer.byteLength(text)>4096)throw new Error('BAD_REQUEST');}try{return JSON.parse(text);}catch{throw new Error('BAD_REQUEST');}}
const server=createServer(async(req,res)=>{
 try{
  const pathName=decodeURIComponent(new URL(req.url,'http://localhost').pathname);
  if(pathName==='/health')return json(res,200,{ok:true});
  if(pathName.startsWith('/api/')){
   if(pathName==='/api/session'&&req.method==='GET'){const token=cookie(req);const data=token?await rpc('session',{p_token:token}):{name:null};return json(res,200,{name:data.name});}
   if(req.method!=='POST')return json(res,405,{error:'请求方式不支持。'});
   const origin=req.headers.origin;
   if(!origin||new URL(origin).host!==req.headers.host)return json(res,403,{error:'请从游戏页面提交。'});
   if(req.headers['content-type']?.split(';')[0]!=='application/json')return json(res,415,{error:'请求格式不支持。'});
   const ip=(req.headers['x-forwarded-for']||req.socket.remoteAddress||'unknown').split(',')[0];const now=Date.now();let item=limits.get(ip);if(!item||item.until<now){item={count:0,until:now+60000};limits.set(ip,item);}if(++item.count>20)return json(res,429,{error:'操作过于频繁，请稍后重试。'});
   if(pathName==='/api/logout'){const token=cookie(req);if(token)await rpc('logout',{p_token:token});return json(res,200,{ok:true},{'Set-Cookie':'qize_session=; HttpOnly; Secure; SameSite=Lax; Path=/; Max-Age=0'});}
   const action=pathName.slice(5);if(!['login','register'].includes(action))return json(res,404,{error:'接口不存在。'});
   const data=await body(req);const name=typeof data.name==='string'?data.name.normalize('NFKC').trim():'';const password=data.password;
   if(!/^[\p{L}\p{N}_-]{2,24}$/u.test(name)||typeof password!=='string'||Buffer.byteLength(password)<6||Buffer.byteLength(password)>72)return json(res,400,{error:'名字需为2–24个字（文字、数字、下划线）；密码需为6–72字节。'});
   const result=await rpc(action,{p_name:name,p_password:password});if(result.error)return json(res,400,{error:result.error});
   return json(res,200,{name:result.name},{'Set-Cookie':`qize_session=${result.token}; HttpOnly; Secure; SameSite=Lax; Path=/; Max-Age=604800`});
  }
  if(req.method!=='GET'&&req.method!=='HEAD'){res.writeHead(405);return res.end();}
  const path=resolve(root,'.'+(pathName==='/'?'/index.html':pathName));if(!path.startsWith(root)){res.writeHead(403);return res.end();}
  const data=await readFile(path);res.writeHead(200,{'Content-Type':types[extname(path)]||'application/octet-stream','X-Content-Type-Options':'nosniff','Cache-Control':'no-cache'});res.end(req.method==='HEAD'?undefined:data);
 }catch(error){if(error.message==='BAD_REQUEST')return json(res,400,{error:'请求内容无效。'});if(error.message.startsWith('DATABASE')||error.name==='TimeoutError')return json(res,503,{error:'身份档案暂时无法连接，请稍后重试。'});if(error.code==='ENOENT')return json(res,404,{error:'页面不存在。'});return json(res,500,{error:'暂时无法完成操作，请稍后重试。'});}
});
setInterval(()=>{for(const [key,item] of limits)if(item.until<Date.now())limits.delete(key);},60000).unref();
server.listen(Number(process.env.PORT||3000),'0.0.0.0');
process.on('SIGTERM',()=>server.close(()=>process.exit(0)));
