import base64
import os
import sys

def emit_leb128(val):
    """编码 LEB128 变长整数。"""
    res = bytearray()
    while True:
        byte = val & 0x7f
        val >>= 7
        if val == 0:
            res.append(byte)
            break
        res.append(byte | 0x80)
    return res

def main():
    if len(sys.argv) < 3:
        print("Usage: python embed_map.py <wasm_path> <map_path>")
        sys.exit(1)

    wasm_path = sys.argv[1]
    map_path = sys.argv[2]

    if not os.path.exists(map_path):
        print(f">>> Warning: {map_path} not found, skipping embedding.")
        return

    print(f">>> Reading {map_path}...")
    with open(map_path, 'rb') as f:
        b64_map = base64.b64encode(f.read()).decode('utf-8')
        data_uri = f'data:application/json;base64,{b64_map}'
    
    # WebAssembly Custom Section 格式:
    # [ID: 0] [Payload Len: LEB128] [Name Len: LEB128] [Name: sourceMappingURL] [Content: data_uri]
    name = 'sourceMappingURL'.encode('utf-8')
    content = data_uri.encode('utf-8')
    
    name_len_leb = emit_leb128(len(name))
    payload_len = len(name_len_leb) + len(name) + len(content)
    payload_len_leb = emit_leb128(payload_len)
    
    # 构造字节流
    section_data = b'\x00' + payload_len_leb + name_len_leb + name + content
    
    print(f">>> Appending SourceMap to {wasm_path}...")
    with open(wasm_path, 'ab') as f:
        f.write(section_data)
    
    # 注入后删除物理文件
    os.remove(map_path)
    print(">>> SourceMap embedded successfully (Pure Python).")

if __name__ == "__main__":
    main()
