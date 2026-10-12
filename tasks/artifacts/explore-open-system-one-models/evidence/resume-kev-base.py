"""续传本任务超时中断的Kev底座，完整SHA256匹配Hub LFS元数据后才提交缓存。"""
import hashlib
import json
from pathlib import Path
import urllib.request

ROOT = Path(__file__).resolve().parent
repo = 'Qwen/Qwen3.5-0.8B-Base'
revision = 'dc7cdfe2ee4154fa7e30f5b51ca41bfa40174e68'
filename = 'model.safetensors-00001-of-00001.safetensors'
with urllib.request.urlopen(f'https://huggingface.co/api/models/{repo}/tree/{revision}', timeout=30) as response:
    metadata = next(item for item in json.load(response) if item['path'] == filename)
sha = metadata['lfs']['oid']
size = metadata['size']
folder = Path.home() / '.cache/huggingface/hub/models--Qwen--Qwen3.5-0.8B-Base/blobs'
partial = folder / (sha + '.3327d7d2.incomplete')
start = partial.stat().st_size
assert 0 < start < size
request = urllib.request.Request(f'https://huggingface.co/{repo}/resolve/{revision}/{filename}', headers={'Range': f'bytes={start}-'})
with urllib.request.urlopen(request, timeout=60) as response:
    assert response.status == 206, '服务端未遵守Range，禁止追加'
    assert response.headers['Content-Range'] == f'bytes {start}-{size-1}/{size}'
    with partial.open('ab') as output:
        while chunk := response.read(1024 * 1024):
            output.write(chunk)
assert partial.stat().st_size == size
with partial.open('rb') as source:
    actual = hashlib.file_digest(source, 'sha256').hexdigest()
assert actual == sha
final = folder / sha
assert not final.exists()
partial.rename(final)
result = dict(repo=repo, revision=revision, bytes_resumed=start, total_bytes=size, sha256=actual, verified=True)
(ROOT / 'kev-base-resume.json').write_text(json.dumps(result, indent=2)+'\n')
print(json.dumps(result), flush=True)
