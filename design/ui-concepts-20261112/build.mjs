
import fs from 'node:fs';
const configs=JSON.parse(fs.readFileSync('themes.json','utf8'));
fs.mkdirSync('dist/screenshots',{recursive:true});
const core=fs.readFileSync('core.css','utf8'),corners=fs.readFileSync('corners.css','utf8'),engine=fs.readFileSync('engine.js','utf8');
for(const c of configs){const css=core+'\n'+fs.readFileSync('theme-'+c.id+'.css','utf8')+'\n'+corners;
fs.writeFileSync('dist/'+c.code+'-'+c.id+'.html','<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="color-scheme" content="'+(c.id==='night'?'dark':'light')+'"><title>TimeSand '+c.code+' · '+c.name+'</title><style>'+css+'</style></head><body><script>window.TIMESAND_CONFIG='+JSON.stringify(c)+';<\/script><script>'+engine+'<\/script></body></html>');}
let index=fs.readFileSync('index.template.html','utf8').replace('__CARDS__',configs.map(c=>'<article class="card"><a href="'+c.code+'-'+c.id+'.html" style="display:block;border:0;padding:0;border-radius:0"><img src="screenshots/'+c.id+'-desktop.jpg" alt="'+c.name+'实际HTML桌面截图"></a><div class="body"><h3>'+c.code+' · '+c.name+(c.code==='A'?'<span class="tag">优先推荐</span>':'')+'</h3><p>'+c.description+'</p><div class="links"><a class="primary" href="'+c.code+'-'+c.id+'.html">体验此方案 ↗</a><a href="screenshots/'+c.id+'-phone.png">查看手机首页</a><a href="screenshots/'+c.id+'-phone-bottles.png">查看手机瓶子区</a></div></div></article>').join('')).replace('__OPTIONS__',configs.map(c=>'<option>'+c.code+' · '+c.name+'</option>').join(''));
fs.writeFileSync('dist/index.html',index);
fs.copyFileSync('README.md','dist/README.md');
console.log('Generated five independent, offline HTML prototypes and one index.');
