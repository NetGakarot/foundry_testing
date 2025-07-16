from eth_utils import keccak, to_checksum_address
import json

# 🧾 Define users and amounts
users = [
    {
        "address": "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
        "amount": 25 * 10**18
    },
    {
        "address": "0xA5E4C6932F1fFeE559d6f28E54738b18155E95F9",
        "amount": 25 * 10**18
    },
    {
        "address": "0x8BdB2FaB7891AcCcc2f4B9EF716e0aE45d1f9B26",
        "amount": 25 * 10**18
    },
    {
        "address": "0x222B8C7B435681C886928B9210e26DEbDac3A223",
        "amount": 25 * 10**18
    }
]

def double_hash_leaf(addr: str, amount: int) -> bytes:
    addr_bytes = bytes.fromhex(addr[2:].lower())
    amt_bytes = amount.to_bytes(32, byteorder='big')
    inner = keccak(addr_bytes + amt_bytes)
    return keccak(inner)

def hash_pair(a: bytes, b: bytes) -> bytes:
    return keccak(a + b) if a < b else keccak(b + a)

# Step 1: create leaves
leaves = [double_hash_leaf(user['address'], user['amount']) for user in users]

# Step 2: Build Merkle Tree
def build_merkle_tree(leaves: list) -> list:
    tree = [leaves]
    while len(tree[-1]) > 1:
        level = []
        current = tree[-1]
        for i in range(0, len(current), 2):
            left = current[i]
            right = current[i+1] if i+1 < len(current) else current[i]
            level.append(hash_pair(left, right))
        tree.append(level)
    return tree

tree = build_merkle_tree(leaves)
merkle_root = tree[-1][0].hex()

print(f"\n🔗 Merkle Root: 0x{merkle_root}")

# Step 3: Generate proof for each user
def get_proof(index: int, tree: list) -> list:
    proof = []
    for level in tree[:-1]:
        sibling_index = index ^ 1  # flip last bit
        if sibling_index < len(level):
            proof.append("0x" + level[sibling_index].hex())
        index = index // 2
    return proof

# Step 4: Print everything
for i, user in enumerate(users):
    leaf = leaves[i]
    proof = get_proof(i, tree)
    print(f"\n📤 User: {to_checksum_address(user['address'])}")
    print(f"   Amount: {user['amount']}")
    print(f"   Leaf: 0x{leaf.hex()}")
    print(f"   Proof: {json.dumps(proof)}")
