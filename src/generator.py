import boto3, json, random, sys, time
from concurrent.futures import ThreadPoolExecutor

total, queue_url = int(sys.argv[1]), sys.argv[2]
sqs = boto3.client("sqs", region_name="us-east-2")

def mensaje(i):
    if random.random() < 0.02:
        return "mensaje-corrupto"
    return json.dumps({
        "conductor_id": f"CHOFER-{random.randint(1, 20):03d}",
        "lat": round(-8.11 + random.uniform(-0.05, 0.05), 6),
        "lon": round(-79.03 + random.uniform(-0.05, 0.05), 6),
        "ts": int(time.time()),
    })

def enviar(chunk):
    sqs.send_message_batch(QueueUrl=queue_url, Entries=[
        {"Id": str(i), "MessageBody": mensaje(i)} for i in chunk])

inicio = time.time()
ids = list(range(total))
with ThreadPoolExecutor(5) as ex:
    list(ex.map(enviar, [ids[i:i+10] for i in range(0, total, 10)]))
print(f"{total} mensajes enviados en {time.time()-inicio:.1f}s")