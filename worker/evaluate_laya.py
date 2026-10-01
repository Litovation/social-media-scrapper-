"""Small offline regression probe, not a representative accuracy benchmark."""
import json
import sys
from pathlib import Path
from laya import Router
from laya_worker import POST_QUESTIONS, classify_answers

CASES = [
    {"text":"I am excited to join Framer's marketing team next week. A new chapter in my career.", "forbidden":{"purpose":"offer"}, "cta":False},
    {"text":"Send euros to Kenya using Solana and M-Pesa. We need testers for this banking transfer service.", "forbidden":{"subject":"ai"}},
    {"text":"New identity for Nova: a condensed wordmark and yellow racing graphics. Our finished logo and packaging are shown here.", "expected":{"purpose":"showcase","subject":"branding"}, "cta":False},
    {"text":"Comment FREE and follow me. I'll DM you our free design template pack.", "expected":{"cta_kind":"resource"}, "cta":True},
    {"text":"We have two brand identity project slots for November. Book a discovery call to discuss your company's new identity.", "expected":{"purpose":"offer","cta_kind":"inquiry"}, "cta":True},
    {"text":"2025, shipped. Our year of design work: https://example.com/projects", "forbidden":{"hook":"number_list"}, "cta":False},
]

if __name__ == '__main__':
    router=Router()
    questions={k:POST_QUESTIONS[k] for k in ('purpose','subject','hook','has_cta','cta_kind')}
    results=router.predict_batch([{"state":{"post":c['text']},"questions":questions} for c in CASES],batch_size=8,sort_by_length=True)
    rows=[]
    for case,result in zip(CASES,results):
        ans=(result or {}).get('answers',{})
        normalized=classify_answers(case['text'],ans)
        labels={k:normalized[k] for k in ('purpose','subject','hook','cta_kind')}
        score=normalized['has_cta']
        cta=None if score is None or 0.35<score<0.65 else score>=0.65
        failures=[k for k,v in case.get('forbidden',{}).items() if labels[k]==v]
        failures += ['cta'] if 'cta' in case and cta is not None and cta != case['cta'] else []
        failures += [k for k,v in case.get('expected',{}).items() if labels[k] is not None and labels[k]!=v]
        rows.append({'text':case['text'],'labels':labels,'cta':cta,'cta_score':score,'failures':failures,'answers':ans})
    report={'note':'Six synthetic text cases only. Abstentions are allowed and shown. This is a regression probe, not proof of general accuracy.','cases':rows,'failures':sum(len(r['failures']) for r in rows)}
    output=Path(sys.argv[1]) if len(sys.argv)>1 else Path('laya-evaluation.json')
    output.write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps({'cases':len(rows),'failures':report['failures'],'abstained_choices':sum(v is None for r in rows for v in r['labels'].values())}))
