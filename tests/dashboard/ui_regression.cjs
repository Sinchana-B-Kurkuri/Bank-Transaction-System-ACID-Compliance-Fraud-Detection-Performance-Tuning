// Real-browser dashboard regression. Requires an owned demo server, never direct SQL.
const {chromium}=require('playwright');
const fs=require('fs'),path=require('path');
(async()=>{
 const url=process.argv[2],dir=process.argv[3];
 if(!/^http:\/\/127\.0\.0\.1:\d+$/.test(url||'')||!dir||fs.existsSync(dir))throw Error('Use a loopback server URL and new evidence directory');
 fs.mkdirSync(dir,{recursive:true});
 const browser=await chromium.launch({channel:'msedge',headless:true});
 const p=await browser.newPage({viewport:{width:1440,height:1000}}),errors=[],checks=[];
 p.on('pageerror',e=>errors.push(e.message));
 const check=(name,ok)=>{checks.push({name,status:ok?'PASS':'FAIL'});console.log(`TEST|${ok?'PASS':'FAIL'}|${name}`);if(!ok)throw Error(name);};
 const go=async name=>{await p.locator(`#nav a[href="#${name}"]`).click();await p.waitForFunction(n=>location.hash==='#'+n&&document.querySelector('#nav a[aria-current=page]')?.getAttribute('href')==='#'+n,name);};
 const tab=async name=>{await p.getByRole('tab',{name,exact:true}).click();};
 const form=action=>p.locator(`form[data-action="${action}"]`);
 const post=async action=>{const response=p.waitForResponse(r=>r.url()===url+(action==='rollback'?'/api/rollback':'/api/operate')&&r.request().method()==='POST');await form(action).locator('button').click();const r=await response;await p.waitForFunction(()=>!document.querySelector('#refresh').disabled);return {status:r.status(),body:await r.json()};};
 try{
  await p.goto(url);await p.locator('.hero').waitFor();
  const boot=await p.evaluate(()=>fetch('/api/bootstrap').then(r=>r.json()));check('owned disposable dashboard target',/^bank_a_ci_demo_[a-f0-9]{12}_main$/.test(boot.database));
  check('all twelve navigation links',await p.locator('#nav a').count()===12);
  check('grouped navigation',await p.locator('.nav-group-title').allTextContents().then(v=>v.join(',')==='Banking,Fraud,Database lab'));
  await p.screenshot({path:path.join(dir,'overview.png'),fullPage:true});
  for(const name of ['customers','banking','fraud','review','acid','concurrency','audit','performance','security','architecture','verification']){await go(name);check(name+' renders',await p.locator('#content .panel').count()>0);}
  await go('banking');check('five operation tabs',await p.getByRole('tab').count()===5);check('one visible banking form',await p.locator('form:visible').count()===1);
  await form('deposit').locator('[name="amount"]').fill('13.37');await p.locator('#refresh').click();await p.waitForFunction(()=>!document.querySelector('#refresh').disabled);check('refresh preserves typed amount',await form('deposit').locator('[name="amount"]').inputValue()==='13.37');
  await tab('Withdraw');await tab('Deposit');check('tab change preserves draft',await form('deposit').locator('[name="amount"]').inputValue()==='13.37');
  await go('audit');await go('banking');check('navigation preserves draft',await form('deposit').locator('[name="amount"]').inputValue()==='13.37');
  check('Online disables staff',await form('deposit').locator('[name="employee"]').isDisabled());await form('deposit').locator('[name="channel"]').selectOption('Branch');check('Branch enables staff',await form('deposit').locator('[name="employee"]').isEnabled());await form('deposit').locator('[name="channel"]').selectOption('Online');
  await go('customers');await tab('Register customer');await form('register').locator('[name="name"]').fill('Synthetic <b>Browser UI</b> Customer');let result=await post('register');check('browser registration succeeds',result.body.ok===true);const customer=result.body.procedure_output.trim().split('\n').at(-1);
  await tab('Open account');check('real customer ID propagated',await form('open').locator('[name="customer"]').inputValue()===customer);await form('open').locator('[name="number"]').fill('UI-'+Date.now().toString().slice(-10));result=await post('open');check('browser opening succeeds',result.body.ok===true);const aid=result.body.procedure_output.trim().split('\n').at(-1).split('\t')[0];
  await go('banking');await tab('Deposit');check('new account preferred',await form('deposit').locator('[name="account"]').inputValue()===aid);check('old result hidden on navigation',await p.locator('#result-panel').isHidden());
  await form('deposit').locator('[name="amount"]').fill('10');result=await post('deposit');check('real browser deposit',result.body.ok===true);check('compact successful output',await p.locator('#raw-result').getAttribute('open')===null);await p.screenshot({path:path.join(dir,'deposit-result.png'),fullPage:true});
  await tab('Withdraw');await form('withdraw').locator('[name="amount"]').fill('5');result=await post('withdraw');check('real browser withdrawal',result.body.ok===true);
  await tab('Transfer');await form('transfer').locator('[name="amount"]').fill('2');result=await post('transfer');check('real browser transfer',result.body.ok===true);
  await tab('Statement');result=await post('statement');check('statement output opens',result.body.ok===true&&await p.locator('#raw-result').getAttribute('open')!==null);
  await tab('History');result=await post('history');check('history shows actual ledger',result.body.ok===true&&result.body.procedure_output.includes('transaction_id'));
  await tab('Withdraw');await form('withdraw').locator('[name="amount"]').fill('99999999');result=await post('withdraw');check('native error remains visible',result.status===422&&result.body.error.includes('5004')&&(await p.locator('#operation-state').innerText()).includes('5004'));
  await go('fraud');check('fraud amount independent of banking draft',await form('deposit').locator('[name="amount"]').inputValue()==='6000');check('failed row excluded from latest fraud display',(await p.locator('#content').innerText()).includes('Latest completed transaction'));
  const snap=await p.evaluate(()=>fetch('/api/snapshot').then(r=>r.json()));const latest=snap.transactions.find(t=>t.status==='Completed');check('fraud displays completed transaction ID',(await p.locator('#content').innerText()).includes('Transaction #'+latest.transaction_id));
  await go('review');check('legal review choices for Open flag',await form('review').locator('[name="status"] option').allTextContents().then(v=>v.join(',')==='UnderReview'));result=await post('review');check('review starts',result.body.ok===true);check('legal terminal review choices',await form('review').locator('[name="status"] option').allTextContents().then(v=>v.join(',')==='Confirmed,Dismissed'));result=await post('review');check('review finishes',result.body.ok===true);
  await go('acid');result=await post('rollback');check('real browser atomic rollback',result.body.ok===true&&JSON.stringify(result.body.before)===JSON.stringify(result.body.after));await p.screenshot({path:path.join(dir,'rollback.png'),fullPage:true});
  await go('verification');await p.locator('#run-invariants').click();await p.locator('#invariant-results tbody tr').first().waitFor();check('all six invariants pass',await p.locator('#invariant-results .badge.PASS').count()===6);
  await go('banking');await tab('Deposit');await form('deposit').locator('[name="amount"]').fill('1');
  let posts=0;const watch=r=>{if(r.url()===url+'/api/operate'&&r.method()==='POST')posts++;};p.on('request',watch);
  await p.evaluate(()=>{const f=document.querySelector('form[data-action="deposit"]');f.dispatchEvent(new Event('submit',{bubbles:true,cancelable:true}));f.dispatchEvent(new Event('submit',{bubbles:true,cancelable:true}));});
  await p.waitForFunction(()=>!document.querySelector('#refresh').disabled);p.off('request',watch);check('duplicate submit sends one financial request',posts===1);
  await p.route('**/api/snapshot',r=>r.fulfill({status:500,contentType:'application/json',body:JSON.stringify({error:'UI test: refresh unavailable'})}),{times:1});
  result=await post('deposit');check('successful write survives refresh failure',result.body.ok===true&&(await p.locator('#result-title').innerText())==='Deposit completed');check('refresh failure warns against duplicate retry',(await p.locator('#toast').innerText()).includes('Do not repeat'));
  await p.locator('#refresh').click();await p.waitForFunction(()=>!document.querySelector('#refresh').disabled);
  await go('customers');await p.locator('#content .disclosure').filter({hasText:'Customer directory'}).locator('summary').first().click();check('stored markup renders as literal text',(await p.locator('#content').innerText()).includes('Synthetic <b>Browser UI</b> Customer')&&await p.locator('#content td b').count()===0);
  await go('overview');await p.locator('#start-guide').click();await p.locator('#guide-next').click();check('guide reaches visible registration form',await form('register').isVisible());await p.locator('#guide-close').click();
  await p.setViewportSize({width:390,height:844});await p.locator('#menu-toggle').click();check('mobile menu opens',await p.locator('#menu-toggle').getAttribute('aria-expanded')==='true');await go('banking');check('mobile menu closes after navigation',await p.locator('#nav').isHidden());check('no mobile horizontal overflow',await p.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));await p.screenshot({path:path.join(dir,'mobile.png'),fullPage:true});
  check('no uncaught browser errors',errors.length===0);
 }finally{fs.writeFileSync(path.join(dir,'results.json'),JSON.stringify({checks,errors},null,2));console.log(`TOTAL|PASS=${checks.filter(c=>c.status==='PASS').length}|FAIL=${checks.filter(c=>c.status==='FAIL').length}`);await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
