const $ = (id) => document.getElementById(id);
const screens = ['menu','room','auth'];
let mode = 'login', currentName = null;
function show(screen){screens.forEach(id=>$(id).hidden=id!==screen);window.scrollTo(0,0);}
function updateAccount(name){currentName=name;$('player').textContent=name?`调查员 · ${name}`:'身份未确认';$('clue-title').textContent=name?'身份已确认':'登录游戏';$('clue-note').textContent=name?'查看你的调查身份':'点击查验 · 建立身份';$('stamp').hidden=!name;$('case-note').textContent=name?`欢迎回来，${name}。你的调查身份已记录。`:'第一条线索：确认你的身份。';$('logout').hidden=!name;}
async function request(path,body){const response=await fetch('/api/'+path,{method:body?'POST':'GET',headers:body?{'Content-Type':'application/json'}:{},body:body?JSON.stringify(body):undefined,credentials:'same-origin'});const data=await response.json();if(!response.ok)throw new Error(data.error||'暂时无法连接，请稍后重试。');return data;}
function setMode(next){mode=next;$('auth-title').textContent=mode==='login'?'登录游戏':'建立调查身份';$('auth-sub').textContent=mode==='login'?'每一道红线，都从一个名字开始。':'留下你的名字。记住你的密码。';$('submit').textContent=mode==='login'?'确认身份':'创建账号';$('switch').textContent=mode==='login'?'没有账号？创建一个':'已有账号？返回登录';$('password').autocomplete=mode==='login'?'current-password':'new-password';$('form-message').textContent='';}
$('start').addEventListener('click',()=>{startMusic();if(location.hostname.endsWith('chatgpt.site')){location.href='https://qize-star-game.onrender.com/?scene=board';return;}show('room');});
$('menu-back').addEventListener('click',()=>show('menu'));
$('clue').addEventListener('click',()=>{if(currentName){$('case-note').textContent=`调查员 ${currentName}，身份线索已完成。`;return;}setMode('login');show('auth');$('name').focus({preventScroll:true});});
$('auth-back').addEventListener('click',()=>show('room'));
$('switch').addEventListener('click',()=>setMode(mode==='login'?'register':'login'));
$('auth-form').addEventListener('submit',async(event)=>{event.preventDefault();$('submit').disabled=true;$('form-message').textContent='正在查验身份…';try{const data=await request(mode,{name:$('name').value.trim(),password:$('password').value});$('password').value='';updateAccount(data.name);show('room');}catch(error){$('form-message').textContent=error.message;}finally{$('submit').disabled=false;}});
$('logout').addEventListener('click',async()=>{try{await request('logout',{});updateAccount(null);}catch(error){$('case-note').textContent=error.message;}});
const bgm=$('bgm');bgm.src=window.QIZE_BGM;
function startMusic(){if(!bgm.paused)return;bgm.play().catch(()=>{});}
document.addEventListener('click',startMusic);document.addEventListener('touchend',startMusic,{passive:true});document.addEventListener('keydown',startMusic);startMusic();
let touchX=0,touchY=0;
document.addEventListener('touchstart',event=>{if(event.touches.length!==1)return;touchX=event.touches[0].clientX;touchY=event.touches[0].clientY;startMusic();},{passive:true});
document.addEventListener('touchmove',event=>{if(event.touches.length!==1)return;const dx=event.touches[0].clientX-touchX,dy=event.touches[0].clientY-touchY;const page=document.scrollingElement;if(Math.abs(dx)>Math.abs(dy)||(page.scrollTop<=0&&dy>0)||(page.scrollTop+page.clientHeight>=page.scrollHeight-1&&dy<0)){if(event.cancelable)event.preventDefault();}},{passive:false});
if(new URLSearchParams(location.search).get('scene')==='board')show('room');
if(!location.hostname.endsWith('chatgpt.site'))request('session').then(data=>updateAccount(data.name)).catch(()=>{});
