// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.6.12;

import "@openzeppelin/contracts/proxy/Proxy.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155Holder.sol";

interface IBPool {
    function createPool(
        uint initialSupply,
        uint minimumWeightChangeBlockPeriodParam,
        uint addTokenTimeLockInBlocksParam
    ) external;

    function createPool(uint initialSupply) external;

    function updateWeight(address token, uint newWeight) external;

    function updateWeightsGradually(
        uint[] calldata newWeights,
        uint startBlock,
        uint endBlock
    ) external;

    function pokeWeights() external;

    function commitAddToken(
        address token,
        uint balance,
        uint denormalizedWeight
    ) external;

    function applyAddToken() external;

    function removeToken(address token) external;

    function joinPool(uint poolAmountOut, uint[] calldata maxAmountsIn) external;

    function exitPool(uint poolAmountIn, uint[] calldata minAmountsOut) external;

    function joinswapExternAmountIn(
        address tokenIn,
        uint tokenAmountIn,
        uint minPoolAmountOut
    ) external;

    function joinswapPoolAmountOut(
        address tokenIn,
        uint poolAmountOut,
        uint maxAmountIn
    ) external;

    function exitswapPoolAmountIn(
        address tokenOut,
        uint poolAmountIn,
        uint minAmountOut
    ) external;

    function exitswapExternAmountOut(
        address tokenOut,
        uint tokenAmountOut,
        uint maxPoolAmountIn
    ) external;
}

contract CRPoolExtend is Proxy, ERC1155Holder {
    address public immutable implementation;
    address public immutable exchangeProxy;

    constructor(address _poolImpl, address _exchProxy, bytes memory _data) public {
        implementation = _poolImpl;
        exchangeProxy = _exchProxy;

        if(_data.length > 0) {
            Address.functionDelegateCall(_poolImpl, _data);
        }
    }

    function _implementation() internal view override returns (address) {
        return implementation;
    }

    function _beforeFallback() internal override {
       _onlyExchangeProxy();
    }

    function _onlyExchangeProxy() internal view {
        if (
           msg.sig == bytes4(keccak256("createPool(uint256,uint256,uint256)")) ||
           msg.sig == bytes4(keccak256("createPool(uint256)")) ||
           msg.sig == IBPool.updateWeight.selector ||
           msg.sig == IBPool.updateWeightsGradually.selector ||
           msg.sig == IBPool.pokeWeights.selector ||
           msg.sig == IBPool.commitAddToken.selector ||
           msg.sig == IBPool.applyAddToken.selector ||
           msg.sig == IBPool.removeToken.selector ||
           msg.sig == IBPool.joinPool.selector ||
           msg.sig == IBPool.exitPool.selector ||
           msg.sig == IBPool.joinswapExternAmountIn.selector ||
           msg.sig == IBPool.joinswapPoolAmountOut.selector ||
           msg.sig == IBPool.exitswapPoolAmountIn.selector ||
           msg.sig == IBPool.exitswapExternAmountOut.selector
        ) {
            require(msg.sender == exchangeProxy, "ERR_NOT_EXCHANGE_PROXY");
       }
    }
}
