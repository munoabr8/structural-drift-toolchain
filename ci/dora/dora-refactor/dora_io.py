import json
def load_ndjson(path):
    out=[]; 
    with open(path,'r',encoding='utf-8') as f:
        for ln in f:
            ln=ln.strip()
            if ln: out.append(json.loads(ln))
    return out
def dump_json(obj, fp=None):
    s=json.dumps(obj, indent=2)
    if fp: open(fp,'w',encoding='utf-8').write(s+'\n')
    else: print(s)
