import boto3, os
s3 = boto3.client('s3'); comprehend = boto3.client('comprehend'); OUT=os.environ["OUTPUT_BUCKET"]
def lambda_handler(event, context):
    for rec in event.get("Records", []):
        b = rec["s3"]["bucket"]["name"]; k = rec["s3"]["object"]["key"]
        body = s3.get_object(Bucket=b, Key=k)["Body"].read().decode("utf-8")
        ents = comprehend.detect_pii_entities(Text=body, LanguageCode="en")["Entities"]
        red = mask(body, ents)
        s3.put_object(Bucket=OUT, Key=k, Body=red.encode("utf-8"))
    return {"status":"ok"}
def mask(txt, ents):
    spans = sorted([(e["BeginOffset"], e["EndOffset"]) for e in ents])
    out=[]; prev=0
    for s,e in spans: out += [txt[prev:s], "[REDACTED]"]; prev=e
    out.append(txt[prev:]); return "".join(out)
