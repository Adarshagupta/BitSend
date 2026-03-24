// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20Minimal {
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

library BitSendMerkleProof {
    function verify(bytes32[] memory proof, bytes32 root, bytes32 leaf) internal pure returns (bool) {
        bytes32 computedHash = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            computedHash = _hashPair(computedHash, proof[i]);
        }
        return computedHash == root;
    }

    function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a <= b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }
}

library BitSendECDSA {
    function recover(bytes32 digest, bytes memory signature) internal pure returns (address) {
        if (signature.length != 65) {
            revert InvalidSignatureLength();
        }
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }
        if (v < 27) {
            v += 27;
        }
        if (v != 27 && v != 28) {
            revert InvalidSignatureV();
        }
        address signer = ecrecover(digest, v, r, s);
        if (signer == address(0)) {
            revert InvalidSignature();
        }
        return signer;
    }

    error InvalidSignatureLength();
    error InvalidSignatureV();
    error InvalidSignature();
}

contract BitSendOfflineVoucherEscrow {
    using BitSendMerkleProof for bytes32[];

    struct Escrow {
        address owner;
        address asset;
        uint256 totalAmount;
        uint256 remainingAmount;
        uint64 expiry;
        bytes32 voucherRoot;
        bool refunded;
    }

    struct Voucher {
        bytes32 escrowId;
        bytes32 voucherId;
        uint256 amount;
        uint64 expiry;
        bytes32 nonce;
    }

    mapping(bytes32 => Escrow) public escrows;
    mapping(bytes32 => bool) public claimedVoucherIds;

    event EscrowCreated(
        bytes32 indexed escrowId,
        address indexed owner,
        address indexed asset,
        uint256 amount,
        uint64 expiry,
        bytes32 voucherRoot
    );
    event VoucherClaimed(
        bytes32 indexed escrowId,
        bytes32 indexed voucherId,
        address indexed receiver,
        uint256 amount
    );
    event EscrowRefunded(bytes32 indexed escrowId, address indexed owner, uint256 amount);

    error EscrowAlreadyExists();
    error EscrowNotFound();
    error EscrowExpired();
    error EscrowNotExpired();
    error EscrowRefundedAlready();
    error VoucherClaimedAlready();
    error InvalidVoucherProof();
    error InvalidVoucherExpiry();
    error InvalidAssignmentSigner();
    error ReceiverAddressRequired();
    error AmountExceedsEscrow();
    error NativeValueMismatch();
    error TokenTransferFailed();
    error NativeTransferFailed();
    error Unauthorized();

    function createEscrow(
        bytes32 escrowId,
        address asset,
        uint256 amount,
        uint64 expiry,
        bytes32 voucherRoot
    ) external payable {
        if (escrows[escrowId].owner != address(0)) {
            revert EscrowAlreadyExists();
        }
        if (expiry <= block.timestamp) {
            revert EscrowExpired();
        }
        if (amount == 0) {
            revert AmountExceedsEscrow();
        }

        if (asset == address(0)) {
            if (msg.value != amount) {
                revert NativeValueMismatch();
            }
        } else {
            if (msg.value != 0) {
                revert NativeValueMismatch();
            }
            bool transferred = IERC20Minimal(asset).transferFrom(msg.sender, address(this), amount);
            if (!transferred) {
                revert TokenTransferFailed();
            }
        }

        escrows[escrowId] = Escrow({
            owner: msg.sender,
            asset: asset,
            totalAmount: amount,
            remainingAmount: amount,
            expiry: expiry,
            voucherRoot: voucherRoot,
            refunded: false
        });

        emit EscrowCreated(escrowId, msg.sender, asset, amount, expiry, voucherRoot);
    }

    function claimVoucher(
        bytes32 escrowId,
        bytes32 voucherId,
        uint256 amount,
        uint64 voucherExpiry,
        bytes32 nonce,
        address receiver,
        bytes calldata ownerSignature,
        bytes32[] calldata voucherProof
    ) external {
        Escrow storage escrow = escrows[escrowId];
        if (escrow.owner == address(0)) {
            revert EscrowNotFound();
        }
        if (escrow.refunded) {
            revert EscrowRefundedAlready();
        }
        if (receiver == address(0)) {
            revert ReceiverAddressRequired();
        }
        if (block.timestamp > escrow.expiry) {
            revert EscrowExpired();
        }
        if (block.timestamp > voucherExpiry) {
            revert InvalidVoucherExpiry();
        }
        if (claimedVoucherIds[voucherId]) {
            revert VoucherClaimedAlready();
        }
        if (amount == 0 || amount > escrow.remainingAmount) {
            revert AmountExceedsEscrow();
        }

        Voucher memory voucher = Voucher({
            escrowId: escrowId,
            voucherId: voucherId,
            amount: amount,
            expiry: voucherExpiry,
            nonce: nonce
        });
        bytes32 leaf = voucherLeaf(voucher);
        if (!voucherProof.verify(escrow.voucherRoot, leaf)) {
            revert InvalidVoucherProof();
        }

        bytes32 digest = claimDigest(leaf, receiver);
        address signer = BitSendECDSA.recover(digest, ownerSignature);
        if (signer != escrow.owner) {
            revert InvalidAssignmentSigner();
        }

        claimedVoucherIds[voucherId] = true;
        escrow.remainingAmount -= amount;

        if (escrow.asset == address(0)) {
            (bool success, ) = payable(receiver).call{value: amount}("");
            if (!success) {
                revert NativeTransferFailed();
            }
        } else {
            bool transferred = IERC20Minimal(escrow.asset).transfer(receiver, amount);
            if (!transferred) {
                revert TokenTransferFailed();
            }
        }

        emit VoucherClaimed(escrowId, voucherId, receiver, amount);
    }

    function refundExpiredEscrow(bytes32 escrowId) external {
        Escrow storage escrow = escrows[escrowId];
        if (escrow.owner == address(0)) {
            revert EscrowNotFound();
        }
        if (msg.sender != escrow.owner) {
            revert Unauthorized();
        }
        if (escrow.refunded) {
            revert EscrowRefundedAlready();
        }
        if (block.timestamp <= escrow.expiry) {
            revert EscrowNotExpired();
        }

        escrow.refunded = true;
        uint256 amount = escrow.remainingAmount;
        escrow.remainingAmount = 0;

        if (amount > 0) {
            if (escrow.asset == address(0)) {
                (bool success, ) = payable(escrow.owner).call{value: amount}("");
                if (!success) {
                    revert NativeTransferFailed();
                }
            } else {
                bool transferred = IERC20Minimal(escrow.asset).transfer(escrow.owner, amount);
                if (!transferred) {
                    revert TokenTransferFailed();
                }
            }
        }

        emit EscrowRefunded(escrowId, escrow.owner, amount);
    }

    function voucherLeaf(Voucher memory voucher) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                voucher.escrowId,
                voucher.voucherId,
                voucher.amount,
                voucher.expiry,
                voucher.nonce
            )
        );
    }

    function claimDigest(bytes32 voucherLeafHash, address receiver) public view returns (bytes32) {
        return keccak256(
            abi.encode(
                address(this),
                block.chainid,
                receiver,
                voucherLeafHash
            )
        );
    }
}
