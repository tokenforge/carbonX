// SPDX-License-Identifier: UNLICENSED
// (C) by TokenForge GmbH, Berlin
// Author: Hagen Hübel, hagen@token-forge.io

pragma solidity >=0.8.3;

import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";

import "./ICarbonReceipt.sol";
import "./CarbonX.sol";
import "./ICarbonX.sol";

contract CarbonVault is ERC165, ERC1155Receiver, Ownable {
    using ECDSA for bytes32;
    using Counters for Counters.Counter;

    event CarbonDeposited(
        uint256 indexed tokenId,
        uint256 amount,
        address indexed from,
        address tokenAddress,
        uint256 originalTokenId
    );
    
    event ReceiptTokenChanged(address indexed operator, address indexed oldToken, address indexed newToken);

    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);

    Counters.Counter private _tokenIds;

    ICarbonReceipt private _receiptToken;

    mapping(address => bool) private _supportedTokens;

    constructor(ICarbonReceipt receiptToken_, ICarbonX supportedToken) {
        _receiptToken = receiptToken_;
        addSupportedToken(supportedToken);
    }

    function addSupportedToken(ICarbonX supportedToken) public onlyOwner {
        _supportedTokens[address(supportedToken)] = true;
    }

    function removeSupportedToken(ICarbonX supportedToken) public onlyOwner {
        _supportedTokens[address(supportedToken)] = false;
    }

    function tokenIsSupported(address token) public view returns (bool) {
        return _supportedTokens[token];
    }

    function currentReceiptTokenId() external view returns (uint256) {
        return _tokenIds.current();
    }
    
    function changeReceiptToken(ICarbonReceipt receiptToken_) public onlyOwner {
        require(_receiptToken != receiptToken_, "New token must have another address");
        
        address oldToken = address(_receiptToken);
        _receiptToken = receiptToken_;
        
        emit ReceiptTokenChanged(_msgSender(), oldToken, address(receiptToken_) );
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165, ERC1155Receiver)
        returns (bool)
    {
        return interfaceId == type(ERC1155Receiver).interfaceId || super.supportsInterface(interfaceId);
    }

    function onERC1155Received(
        address operator,
        address from,
        uint256 tokenId,
        uint256 amount,
        bytes memory data
    ) public virtual override returns (bytes4) {
        address originalToken = _msgSender();
        uint256 originalTokenId = tokenId;
        
        require(tokenIsSupported(originalToken), "Token is not supported");

        _tokenIds.increment();
        
        uint256 receiptTokenId = _tokenIds.current();
        
        uint256[] memory tokenIds = _asSingletonArray(tokenId);
        uint256[] memory amounts = _asSingletonArray(amount);

        try ICarbonX(_msgSender()).isTransferIntoVaultAccepted(operator, from, tokenIds, amounts, data) returns (
            bool accepted
        ) {
            if (!accepted) {
                revert("CarbonVault: transfer into vault not accepted");
            }
        } catch Error(string memory reason) {
            revert(reason);
        } catch {
            revert("CarbonVault: transfer to not-compatible implementer");
        }

        _receiptToken.mintReceipt(from, receiptTokenId, amount, originalTokenId, data);

        emit CarbonDeposited(receiptTokenId, amount, from, _msgSender(), originalTokenId);

        try
            ICarbonX(_msgSender()).onTransferIntoVaultSuccessfullyDone(operator, from, tokenIds, amounts, data)
        returns (bytes4 response) {
            if (response != ICarbonX.onTransferIntoVaultSuccessfullyDone.selector) {
                revert("CarbonVault: ICarbonX rejected tokens");
            }
        } catch Error(string memory reason) {
            revert(reason);
        } catch {
            revert("CarbonVault: transfer to not-compatible implementer");
        }

        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] memory tokenIds,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override returns (bytes4) {
        require(tokenIsSupported(_msgSender()), "Token is not supported");

        try ICarbonX(_msgSender()).isTransferIntoVaultAccepted(operator, from, tokenIds, amounts, data) returns (
            bool accepted
        ) {
            if (!accepted) {
                revert("CarbonVault: transfer into vault not accepted");
            }
        } catch Error(string memory reason) {
            revert(reason);
        } catch {
            revert("CarbonVault: transfer to not-compatible implementer");
        }

        // @TODO to be implemented
        //_receiptToken.batchMintReceipt(from, tokenIds, amounts, data);

        try
            ICarbonX(_msgSender()).onTransferIntoVaultSuccessfullyDone(operator, from, tokenIds, amounts, data)
        returns (bytes4 response) {
            if (response != ICarbonX.onTransferIntoVaultSuccessfullyDone.selector) {
                revert("CarbonVault: ICarbonX rejected tokens");
            }
        } catch Error(string memory reason) {
            revert(reason);
        } catch {
            revert("CarbonVault: transfer to not-compatible implementer");
        }

        return this.onERC1155BatchReceived.selector;
    }

    function _asSingletonArray(uint256 element) private pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](1);
        array[0] = element;

        return array;
    }

}
