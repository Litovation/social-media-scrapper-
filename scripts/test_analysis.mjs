import assert from 'node:assert/strict';
import {ctaGuidance, reportName, reliableTrait} from '../public/analysis.js';

const data = {analysis:{coverage:0.9,posts:170},cta_analysis:{paired_accounts:4,paired_difference:0.2,groups:[
  {val:'with_cta',posts:80,accounts:5,low:0.55,high:0.75},
  {val:'no_cta',posts:90,accounts:6,low:0.1,high:0.3}
]}};
assert.equal(ctaGuidance(data).status,'with_cta');
assert.equal(ctaGuidance({...data,analysis:{coverage:0.2}}).status,'collecting');
assert.equal(ctaGuidance({...data,cta_analysis:{...data.cta_analysis,paired_accounts:0}}).status,'collecting');
assert.equal(ctaGuidance({...data,cta_analysis:{...data.cta_analysis,paired_difference:-0.1}}).status,'unclear');
const reversed = structuredClone(data);
[reversed.cta_analysis.groups[0].low,reversed.cta_analysis.groups[1].low]=[0.1,0.55];
[reversed.cta_analysis.groups[0].high,reversed.cta_analysis.groups[1].high]=[0.3,0.75];
reversed.cta_analysis.paired_difference=-0.2;
assert.equal(ctaGuidance(reversed).status,'no_cta');
const overlap=structuredClone(data); overlap.cta_analysis.groups[0].low=0.2;
assert.equal(ctaGuidance(overlap).status,'unclear');
const tiny=structuredClone(data); tiny.cta_analysis.groups[0].posts=5;
assert.equal(ctaGuidance(tiny).status,'collecting');
assert.equal(reliableTrait({posts:5,accounts:1,recommendable:true},data),false);
assert.equal(reportName({generated_at:'2026-10-01T00:00:00Z',window_days:1095}),'agency-signal-report-2026-10-01-all-time.html');
assert.equal(reportName({generated_at:'2026-10-01T00:00:00Z',window_days:30}),'agency-signal-report-2026-10-01-30d.html');
console.log('CTA guidance: stronger CTA, stronger no-CTA, overlapping evidence, conflicting within-account evidence, low coverage and small samples passed. Report periods passed.');
