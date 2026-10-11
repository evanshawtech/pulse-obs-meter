// Development-only: npm install --save-dev playwright; install Chromium separately.
// Run: node tests/browser-tests.cjs
const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const { pathToFileURL } = require('node:url');

(async () => {
  const root = path.resolve(__dirname,'..');
  const evidence = path.join(root,'evidence');
  await fs.mkdir(evidence,{recursive:true});
  const profile = await fs.mkdtemp(path.join(evidence,'browser-profile-'));
  const executablePath = process.env.CHROMIUM_PATH || '/usr/bin/chromium';
  const options = {executablePath,headless:true,viewport:{width:1920,height:1080},downloadsPath:path.join(evidence,'downloads'),acceptDownloads:true};
  let context = await chromium.launchPersistentContext(profile,options);
  const checks = [];
  const errors = [];
  const externalRequests = [];
  const observe = page => {
    page.on('pageerror',error=>errors.push(error.message));
    page.on('request',request=>{if(/^https?:/.test(request.url())) externalRequests.push(request.url());});
  };
  const check = async (name,run) => {await run(); checks.push({name,result:'PASS'}); console.log('PASS',name);};
  let page = await context.newPage(); observe(page);
  const url = pathToFileURL(path.join(root,'overlay.html')).href;
  await page.goto(url);
  const level = async () => Number(await page.locator('#level').textContent());
  const key = async value => {await page.keyboard.press(value);};
  const closePanel = async () => {await key('Escape'); await page.locator('body').click({position:{x:2,y:2}});};
  const openPanel = async () => {await key('c'); assert.equal(await page.locator('#settings').isVisible(),true);};
  await check('Initial 0/5; transparent source; controls hidden',async()=>{
    assert.equal(await level(),0);
    assert.equal(await page.locator('#settings').isHidden(),true);
    assert.equal(await page.locator('body').evaluate(el=>getComputedStyle(el).backgroundColor),'rgba(0, 0, 0, 0)');
    assert.equal(await page.locator('body').evaluate(el=>el.classList.contains('preview')),false);
  });
  await check('100 rapid mixed physical key presses match independent clamped oracle after every event',async()=>{
    let expected = 0;
    const sequence = Array.from({length:100},(_,i)=>i%13===0?'r':i%7<4?'ArrowRight':'ArrowLeft');
    const start = Date.now();
    for(const action of sequence){
      expected = action==='r'?0:Math.max(0,Math.min(5,expected+(action==='ArrowRight'?1:-1)));
      await key(action); assert.equal(await level(),expected);
      assert.equal(await page.locator('.segment.active').count(),expected);
    }
    checks.push({name:'100 action timing',milliseconds:Date.now()-start});
  });
  await check('100 same-tick actions update synchronously without dropped or stale state',async()=>{
    const actual=await page.evaluate(()=>{
      const output=[];
      for(let i=0;i<100;i++){
        const key=i%19===0?'r':i%9<5?'+':'-';
        document.dispatchEvent(new KeyboardEvent('keydown',{key,bubbles:true}));
        output.push({key,level:Number(document.querySelector('#level').textContent)});
      }
      return output;
    });
    let expected=0;
    for(const entry of actual){expected=entry.key==='r'?0:Math.max(0,Math.min(5,expected+(entry.key==='+'?1:-1)));assert.equal(entry.level,expected);}
  });
  await check('0 and 5 bounds; plus/minus variants; reset; extra effect only entering 5',async()=>{
    await key('r'); for(let i=0;i<10;i++)await key('ArrowLeft'); assert.equal(await level(),0);
    for(let i=0;i<5;i++)await key('='); assert.equal(await level(),5);
    assert.equal(await page.locator('#meter').evaluate(el=>el.classList.contains('celebrate')),true);
    await page.waitForTimeout(1050);
    for(let i=0;i<10;i++)await key('ArrowRight'); assert.equal(await level(),5);
    assert.equal(await page.locator('#meter').evaluate(el=>el.classList.contains('celebrate')),false);
    await key('-'); assert.equal(await level(),4);
    await key('+'); assert.equal(await level(),5);
    await key('r'); assert.equal(await level(),0);
    assert.equal(await page.locator('#meter').evaluate(el=>el.classList.contains('celebrate')),false);
  });
  await check('Control buttons, bounds disabling, close/reopen, focus trap and Escape',async()=>{
    await openPanel(); assert.equal(await page.locator('#decrement').isDisabled(),true);
    await page.locator('#increment').click(); assert.equal(await level(),1);
    await page.locator('#decrement').click(); assert.equal(await level(),0);
    for(let i=0;i<5;i++)await page.locator('#increment').click();
    assert.equal(await page.locator('#increment').isDisabled(),true);
    await page.locator('#reset').click(); assert.equal(await level(),0);
    await page.locator('#close-controls').focus(); await key('Shift+Tab');
    assert.equal(await page.locator('#export').evaluate(el=>el===document.activeElement),true);
    await key('Tab'); assert.equal(await page.locator('#close-controls').evaluate(el=>el===document.activeElement),true);
    await closePanel(); assert.equal(await page.locator('#settings').isHidden(),true);
    await openPanel(); await page.locator('#close-controls').click();
    assert.equal(await page.locator('#settings').isHidden(),true);
  });
  await check('No-source-edit title/colors; text fields do not activate keyboard commands',async()=>{
    await openPanel();
    await page.locator('#title-input').fill('Aurora studio');
    await page.locator('#title-input').press('r'); await page.locator('#title-input').press('+');
    assert.equal(await level(),0); assert.equal(await page.locator('#settings').isVisible(),true);
    await page.locator('#title-input').fill('Aurora streak');
    await page.locator('#subtitle-input').fill('STUDIO / LIVE');
    for(const [id,value] of [['primary-input','#76baff'],['secondary-input','#f9d985']]){
      await page.locator('#'+id).evaluate((el,v)=>{el.value=v;el.dispatchEvent(new Event('input',{bubbles:true}));},value);
    }
    assert.equal(await page.locator('#title').textContent(),'Aurora streak');
    assert.equal(await page.locator('#subtitle').textContent(),'STUDIO / LIVE');
    assert.equal(await page.locator('html').evaluate(el=>el.style.getPropertyValue('--primary')),'#76baff');
    await closePanel(); await key('ArrowRight');await key('ArrowRight');await key('ArrowRight');
  });
  await check('Reload restores exact level, title and colors; panel stays hidden',async()=>{
    await page.reload(); assert.equal(await level(),3);
    assert.equal(await page.locator('#title').textContent(),'Aurora streak');
    assert.equal(await page.locator('html').evaluate(el=>el.style.getPropertyValue('--secondary')),'#f9d985');
    assert.equal(await page.locator('#settings').isHidden(),true);
  });
  await check('Browser process restart restores local-file settings from the same profile',async()=>{
    await context.close(); context=await chromium.launchPersistentContext(profile,options);
    page=await context.newPage();observe(page);await page.goto(url);
    assert.equal(await level(),3);assert.equal(await page.locator('#title').textContent(),'Aurora streak');
  });
  let exportedPath;
  await check('Portable export opens in fresh browser profile with embedded settings/level; no preview UI',async()=>{
    await openPanel();
    const downloadPromise=page.waitForEvent('download');await page.locator('#export').click();
    const download=await downloadPromise;exportedPath=path.join(profile,'configured.html');await download.saveAs(exportedPath);
    const browser=await chromium.launch(options); const fresh=await browser.newContext({viewport:{width:1920,height:1080}});
    const imported=await fresh.newPage();observe(imported);await imported.goto(pathToFileURL(exportedPath).href);
    assert.equal(await imported.locator('#level').textContent(),'3');
    assert.equal(await imported.locator('#title').textContent(),'Aurora streak');
    assert.equal(await imported.locator('html').evaluate(el=>el.style.getPropertyValue('--primary')),'#76baff');
    assert.equal(await imported.locator('body').evaluate(el=>el.classList.contains('preview')),false);
    assert.equal(await imported.locator('#settings').isHidden(),true);
    await imported.keyboard.press('ArrowRight');assert.equal(await imported.locator('#level').textContent(),'4');
    await imported.reload();assert.equal(await imported.locator('#level').textContent(),'4');
    await browser.close();await closePanel();
  });
  await check('HTML-like titles stay text through export and reload',async()=>{
    await openPanel();const title='</script><img src=x onerror=alert(1)>';
    await page.locator('#title-input').fill(title);
    const promise=page.waitForEvent('download');await page.locator('#export').click();
    const file=path.join(profile,'escaped.html');await(await promise).saveAs(file);
    const escaped=await context.newPage();observe(escaped);await escaped.goto(pathToFileURL(file).href);
    assert.equal(await escaped.locator('#title').textContent(),title);
    assert.equal(await escaped.locator('img').count(),0);
    await escaped.close();await page.locator('#title-input').fill('Aurora streak');await closePanel();
  });
  await check('Malformed and out-of-range storage recovers and clamps safely',async()=>{
    await page.evaluate(()=>localStorage.setItem('pulse-meter:pulse-sample-v1','broken-json'));await page.reload();assert.equal(await level(),0);
    await page.evaluate(()=>localStorage.setItem('pulse-meter:pulse-sample-v1',JSON.stringify({schema:1,level:999,config:{title:9,primary:'url(https://example.invalid)',secondary:'#abzzzz'}})));
    await page.reload();assert.equal(await level(),5);assert.equal(await page.locator('#title').textContent(),'Build the moment');
    assert.equal(await page.locator('html').evaluate(el=>el.style.getPropertyValue('--primary')),'#ff794f');
    await page.evaluate(()=>localStorage.setItem('pulse-meter:pulse-sample-v1',JSON.stringify({schema:1,level:-4,config:{}})));
    await page.reload();assert.equal(await level(),0);
  });
  await check('Storage denial is visible and session controls still work',async()=>{
    const blocked=await context.newPage();observe(blocked);
    await blocked.addInitScript(()=>Object.defineProperty(window,'localStorage',{get(){throw new DOMException('Blocked','SecurityError');}}));
    await blocked.goto(url);await blocked.keyboard.press('+');assert.equal(await blocked.locator('#level').textContent(),'1');
    await blocked.keyboard.press('c');assert.match(await blocked.locator('#save-status').textContent(),/Storage unavailable/);await blocked.close();
  });
  await check('Reduced-motion preference removes celebration and preserves correct state',async()=>{
    await page.emulateMedia({reducedMotion:'reduce'});await key('r');for(let i=0;i<5;i++)await key('+');
    assert.equal(await level(),5);assert.equal(await page.locator('#meter').evaluate(el=>el.classList.contains('celebrate')),false);
    await page.emulateMedia({reducedMotion:'no-preference'});await openPanel();await page.locator('#motion-input').check();await closePanel();
    await key('-');await key('+');assert.equal(await page.locator('#meter').evaluate(el=>el.classList.contains('celebrate')),false);
    await openPanel();await page.locator('#motion-input').uncheck();await closePanel();
  });
  await check('Long title fits 16:9 and 9:16 without viewport overflow; transparent screenshots',async()=>{
    await openPanel();await page.locator('#title-input').fill('Forty character title for streaming test!');await closePanel();
    for(const size of [{width:1920,height:1080},{width:1080,height:1920},{width:390,height:844}]){
      await page.setViewportSize(size);
      const bounds=await page.locator('#meter').boundingBox();
      assert.ok(bounds.x>=0&&bounds.y>=0&&bounds.x+bounds.width<=size.width&&bounds.y+bounds.height<=size.height);
      const dimensions=await page.evaluate(()=>({width:document.documentElement.scrollWidth,height:document.documentElement.scrollHeight}));
      assert.equal(dimensions.width,size.width);assert.equal(dimensions.height,size.height);
    }
    await openPanel();await page.locator('#title-input').fill('Build the moment');await closePanel();await key('r');await key('+');await key('+');await key('+');
    await page.setViewportSize({width:1920,height:1080});await page.screenshot({path:path.join(evidence,'transparent-16x9.png'),omitBackground:true});
    await page.setViewportSize({width:1080,height:1920});await page.screenshot({path:path.join(evidence,'transparent-9x16.png'),omitBackground:true});
  });
  await check('Polished browser previews captured at 16:9 and 9:16, plus finish state',async()=>{
    await page.setViewportSize({width:1600,height:900});await page.goto(url+'?preview=1');await page.screenshot({path:path.join(evidence,'preview-16x9.png')});
    await page.setViewportSize({width:900,height:1600});await page.screenshot({path:path.join(evidence,'preview-9x16.png')});
    await page.setViewportSize({width:1600,height:900});await key('+');await key('+');await page.waitForTimeout(1000);await page.screenshot({path:path.join(evidence,'preview-overdrive.png')});
    await openPanel();await page.screenshot({path:path.join(evidence,'controls.png')});
  });
  await check('Zero external network requests and zero uncaught JavaScript errors',async()=>{assert.deepEqual(externalRequests,[]);assert.deepEqual(errors,[]);});
  const report={timestamp:new Date().toISOString(),browser:await context.browser().version(),platform:process.platform,sourceProtocol:'file:',obsTested:false,checks,externalRequests,uncaughtErrors:errors};
  await fs.writeFile(path.join(evidence,'test-report.json'),JSON.stringify(report,null,2)+'\n');
  await context.close();await fs.rm(profile,{recursive:true,force:true});
  console.log('\nAll checks passed. OBS was not run.');
})().catch(error=>{console.error(error);process.exit(1);});
