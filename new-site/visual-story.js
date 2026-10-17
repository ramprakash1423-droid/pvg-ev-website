'use strict';
// Scrolling selects the story image on every screen; reduced-motion and no-JS views retain the static scenes.
for(const journey of document.querySelectorAll('[data-journey]')){
 const stage=journey.querySelector('.journey-stage');
 const steps=[...journey.querySelectorAll('[data-journey-step]')];
 const frames=[...journey.querySelectorAll('[data-frame]')];
 const buttons=[...journey.querySelectorAll('[data-jump]')];
 if(!stage||!steps.length||frames.length!==steps.length)continue;
 const motion=matchMedia('(prefers-reduced-motion:reduce)');
 let enabled=false,scheduled=false,current=-1;
 const select=index=>{if(current===index)return;current=index;frames.forEach((frame,i)=>{frame.classList.toggle('is-active',i===index);frame.setAttribute('aria-hidden',String(i!==index));});buttons.forEach((button,i)=>{if(i===index)button.setAttribute('aria-current','step');else button.removeAttribute('aria-current');});};
 const stacked=()=>steps[0].getBoundingClientRect().left<stage.getBoundingClientRect().right;
 const update=()=>{
  scheduled=false;if(!enabled)return;
  // On phones, follow the text in the space below the pinned image.
  const imageBottom=stage.getBoundingClientRect().bottom;
  const centre=stacked()?Math.min(innerHeight*.85,imageBottom+Math.max(0,innerHeight-imageBottom)*.45):innerHeight*.55;
  let closest=0,distance=Infinity;
  steps.forEach((step,i)=>{const r=step.getBoundingClientRect(),d=Math.abs(r.top+r.height/2-centre);if(d<distance){distance=d;closest=i;}});
  select(closest);
 };
 const schedule=()=>{if(enabled&&!scheduled){scheduled=true;requestAnimationFrame(update);}};
 const configure=()=>{enabled=!motion.matches;journey.classList.toggle('journey-enhanced',enabled);if(enabled)update();};
 buttons.forEach((button,i)=>button.addEventListener('click',()=>{
  const behavior=motion.matches?'auto':'smooth';
  if(stacked()){
   const offset=parseFloat(getComputedStyle(stage).top)+stage.getBoundingClientRect().height+16;
   window.scrollTo({top:scrollY+steps[i].getBoundingClientRect().top-offset,behavior});
  }else steps[i].scrollIntoView({block:'center',behavior});
 }));
 motion.addEventListener('change',configure);
 addEventListener('scroll',schedule,{passive:true});addEventListener('resize',schedule);configure();
}
const sectionLinks=[...document.querySelectorAll('.visual-section-nav a')];
if(sectionLinks.length&&'IntersectionObserver' in window){
 const observer=new IntersectionObserver(entries=>{for(const entry of entries)if(entry.isIntersecting)sectionLinks.forEach(link=>{if(link.hash===`#${entry.target.id}`)link.setAttribute('aria-current','location');else link.removeAttribute('aria-current');});},{rootMargin:'-20% 0px -60% 0px'});
 sectionLinks.forEach(link=>{const section=document.getElementById(link.hash.slice(1));if(section)observer.observe(section);});
}
