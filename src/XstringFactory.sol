// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "burve-contracts/src/interfaces/IBurveFactory.sol";
import "burve-contracts/src/hooks/SBTWithAirdropHook.sol";
import "./Vault.sol";

contract XstringFactory is Vault {
    using SafeERC20 for IERC20;
    using MessageHashUtils for bytes;
    event LogXstringTokenDeployed(string tokenType, string bondingCurveType, address deployedAddr, uint256 id);
    event Airdropped(address indexed tokenAddr, uint256 paidAmount, bytes32 root, uint256 seed);
    IBurveFactory public immutable burveFactory;
    SBTWithAirdropHook public immutable airdropHook;
    mapping(uint256 => address) public tokens;

    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");
    constructor(address _burveFactory, address _airdropHook) {
        burveFactory = IBurveFactory(_burveFactory);
        airdropHook = SBTWithAirdropHook(_airdropHook);
    }

    function deployToken(IBurveFactory.TokenInfo memory token, uint256 id, uint256 deadline, bytes32 r, bytes32 s, uint8 v) public payable returns (address) {
        address signer = ecrecover(abi.encode(token, id, deadline).toEthSignedMessageHash(), v, r, s);
        require(hasRole(CONTROLLER_ROLE, signer), "invalid sig");
        require(tokens[id] == address(0));
        token.projectAdmin = address(this);
        address[] memory hooks = new address[](1);
        bytes[] memory datas = new bytes[](1);
        datas[0] = abi.encode(deadline);
        hooks[0] = address(airdropHook);
        address tokenAddr = burveFactory.deployTokenWithHooks(token, 0, hooks, datas);
        tokens[id] = tokenAddr;
        emit LogXstringTokenDeployed(token.tokenType, token.bondingCurveType, tokenAddr, id);
        return tokenAddr;
    }

    function airdrop(address token, uint256 paidAmount, bytes32 root, uint256 seed, bytes32 r, bytes32 s, uint8 v) external {
        address signer = ecrecover(abi.encode(token, paidAmount, root, seed).toEthSignedMessageHash(), v, r, s);
        require(hasRole(CONTROLLER_ROLE, signer), "invalid sig");
        address raisingToken = IBurveToken(token).getRaisingToken();
        IERC20(raisingToken).safeApprove(token, paidAmount);
        airdropHook.finalAirdrop(token, paidAmount, root);
        emit Airdropped(token, paidAmount, root, seed);
    }

    function setMetadata(address token, string calldata meta, bytes32 r, bytes32 s, uint8 v) external payable {
        address signer = ecrecover(abi.encode(token, meta).toEthSignedMessageHash(), v, r, s);
        require(hasRole(CONTROLLER_ROLE, signer), "invalid sig");
        IBurveToken(token).setMetadata(meta);
    }
}
