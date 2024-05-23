// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/token/ERC20/utils/SafeERC20.sol";

contract Vault is AccessControl {
    using SafeERC20 for IERC20;
    using MessageHashUtils for bytes;

    event Deposited(address indexed token, address indexed user, uint256 amount);
    event Withdrew(address indexed token, address indexed user, uint256 amount);

    bytes32 public constant WITHDRAWER_ROLE = keccak256("WITHDRAWER_ROLE");

    mapping(uint256 => bool) public withdrawMap;

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function deposit(address token, uint256 amount) public payable {
        address user = msg.sender;
        emit Deposited(token, user, _transferFrom(token, user, amount));
    }

    function withdraw(uint256 withdrawId, address token, uint256 amount, bytes32 r, bytes32 s, uint8 v) public {
        address user = msg.sender;
        address signer = ecrecover(abi.encode(withdrawId, user, token, amount).toEthSignedMessageHash(), v, r, s);
        require(hasRole(WITHDRAWER_ROLE, signer), "invalid sig");
        require(!withdrawMap[withdrawId], "withdrew");
        withdrawMap[withdrawId] = true;
        _transferInternal(token, user, amount);
        emit Withdrew(token, user, amount);
    }

    function _transferFrom(address token, address from, uint256 amount) internal virtual returns (uint256 actualAmount) {
        if (token == address(0)) {
            require(amount == msg.value, "invalid value");
            return amount;
        } else {
            uint256 balanceBefore = IERC20(token).balanceOf(address(this));
            IERC20(token).safeTransferFrom(from, address(this), amount);
            actualAmount = IERC20(token).balanceOf(address(this)) - balanceBefore;
        }
    }

    function _transferInternal(address token, address account, uint256 amount) internal virtual {
        if (token == address(0)) {
            require(address(this).balance >= amount, "not enough balance");
            (bool success, ) = account.call{value: amount, gas: 30000}("");
            require(success, "Transfer: failed");
        } else {
            IERC20(token).safeTransfer(account, amount);
        }
    }
}
