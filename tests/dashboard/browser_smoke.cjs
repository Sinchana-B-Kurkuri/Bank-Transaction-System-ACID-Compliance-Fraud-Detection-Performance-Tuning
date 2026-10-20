// Optional browser QA: installed Edge + Playwright, no download and no app dependency.
const {chromium}=require('playwright');
const fs=require('fs');
const path=require('path');
(async()=>{
 const directory=process.argv[2];if(!directory||fs.existsSync(directory))throw Error('Choose a new evidence directory');fs.mkdirSync(directory,{recursive:true});
 const browser=await chromium.launch({channel:'msedge',headless:true});
 const page=await browser.newPage({viewport:{width:1440,height:1050},deviceScaleFactor:1});
 const errors=[];const checks=[];
 page.on('pageerror',e=>errors.push(e.message));
 function check(name,ok){checks.push({test:name,status:ok?'PASS':'FAIL'});console.log(`TEST|${ok?'PASS':'FAIL'}|${name}`);if(!ok)throw Error(name);}
 try{
  await page.goto('http://127.0.0.1:5000');
  await page.locator('.hero').waitFor();
  check('live overview rendered',await page.locator('.metric-value').count()===5);
  check('twelve navigation destinations',await page.locator('#nav a').count()===12);
  check('visible non-security banner',(await page.locator('.security-banner').innerText()).includes('NON-SECURITY DEMO'));
  await page.screenshot({path:path.join(directory,'01-overview.png'),fullPage:true});
  await page.locator('#start-guide').click();
  await page.locator('#guide-next').click();
  await page.waitForFunction(()=>location.hash==='#customers');
  check('guided navigation reaches customer forms',await page.locator('form[data-action="register"]').count()===1);
  check('stored markup escaped',(await page.locator('body').innerText()).includes('Synthetic <b>Dashboard</b> Customer'));
  const registration=page.locator('form[data-action="register"]');
  await registration.getByRole('button',{name:'Register customer',exact:true}).click();
  await page.waitForFunction(()=>document.querySelector('#result-output').textContent.startsWith('customer_id'));
  const customerId=(await page.locator('#result-output').innerText()).trim().split('\n').at(-1).trim();
  check('browser registration propagates real customer ID',await page.locator('form[data-action="open"] select[name="customer"]').inputValue()===customerId);
  const opening=page.locator('form[data-action="open"]');
  await opening.locator('[name="number"]').fill('BROWSER-'+Date.now().toString().slice(-9));
  await opening.getByRole('button',{name:'Open with Completed deposit',exact:true}).click();
  await page.waitForFunction(()=>document.querySelector('#result-output').textContent.startsWith('account_id'));
  const openedId=(await page.locator('#result-output').innerText()).trim().split('\n').at(-1).split('\t')[0];
  check('browser account opening returns actual ID',Number(openedId)>0);
  await page.locator('#guide-close').click();
  const routes=[['banking','Banking Transactions'],['fraud','Fraud Detection'],['review','Fraud Review'],['acid','ACID & Rollback'],['concurrency','Concurrency & Isolation'],['audit','Audit Logs'],['performance','Performance & Indexing'],['security','RBAC & Security'],['architecture','Database Architecture'],['verification','Project Verification']];
  for(const [route,title]of routes){await page.locator(`#nav a[href="#${route}"]`).click();await page.waitForFunction(t=>document.querySelector('#page-title').textContent===t,title);check(`${route} view renders`,(await page.locator('#content .panel').count())>0);if(route==='banking')check('new account selected without fixed IDs',await page.locator('form[data-action="deposit"] select[name="account"]').inputValue()===openedId);if(['fraud','performance','architecture','audit'].includes(route))await page.screenshot({path:path.join(directory,route+'.png'),fullPage:true});}
  await page.locator('#run-invariants').click();
  await page.locator('#invariant-results tbody tr').first().waitFor();
  check('six live invariant rows in browser',await page.locator('#invariant-results tbody tr').count()===6);
  check('all live invariant badges PASS',await page.locator('#invariant-results .badge.PASS').count()===6);
  await page.screenshot({path:path.join(directory,'verification.png'),fullPage:true});
  await page.locator('#nav a[href="#banking"]').click();
  const form=page.locator('form[data-action="deposit"]');await form.locator('[name="amount"]').fill('10');
  await form.getByRole('button',{name:'Post deposit',exact:true}).click();
  await page.waitForFunction(()=>document.querySelector('#result-output').textContent.includes('balance_after'));
  check('live deposit submitted through browser',(await page.locator('#result-output').innerText()).includes('transaction_id'));
  await page.screenshot({path:path.join(directory,'banking-operation.png'),fullPage:true});
  await page.setViewportSize({width:390,height:844});await page.locator('#nav a[href="#overview"]').click();
  check('mobile layout has no horizontal page overflow',await page.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth));
  await page.screenshot({path:path.join(directory,'mobile-overview.png'),fullPage:true});
  check('no uncaught JavaScript errors',errors.length===0);
 }finally{fs.writeFileSync(path.join(directory,'results.json'),JSON.stringify({checks,errors},null,2));await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
