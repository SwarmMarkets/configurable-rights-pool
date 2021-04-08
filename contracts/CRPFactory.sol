// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.6.12;

// Needed to handle structures externally
pragma experimental ABIEncoderV2;

// Imports

import "./CRPoolExtend.sol";
import { RightsManager } from "../libraries/RightsManager.sol";
import "../libraries/BalancerConstants.sol";
import "./utils/Authorizable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

// Contracts

interface IPermissionManager {
    function assignItem(uint256 _itemId, address[] memory _accounts) external;
}

/**
 * @author Balancer Labs
 * @title Configurable Rights Pool Factory - create parameterized smart pools
 * @dev Rights are held in a corresponding struct in ConfigurableRightsPool
 *      Index values are as follows:
 *      0: canPauseSwapping - can setPublicSwap back to false after turning it on
 *                            by default, it is off on initialization and can only be turned on
 *      1: canChangeSwapFee - can setSwapFee after initialization (by default, it is fixed at create time)
 *      2: canChangeWeights - can bind new token weights (allowed by default in base pool)
 *      3: canAddRemoveTokens - can bind/unbind tokens (allowed by default in base pool)
 *      4: canWhitelistLPs - if set, only whitelisted addresses can join pools
 *                           (enables private pools with more than one LP)
 *      5: canChangeCap - can change the BSP cap (max # of pool tokens)
 */
contract CRPFactory is Authorizable {
    struct PoolParams {
        string poolTokenSymbol;
        string poolTokenName;
        address[] constituentTokens;
        uint[] tokenBalances;
        uint[] tokenWeights;
        uint swapFee;
    }

    // State variables
    address public blabs;
    address public crpImpl;
    address public exchangeProxy;
    address public permissionManager;

    // Keep a list of all Configurable Rights Pools
    mapping(address=>bool) private _isCrp;

    // Event declarations

    // Log the address of each new smart pool, and its creator
    event LogNewCrp(
        address indexed caller,
        address indexed pool
    );

    event LogBlabs(
        address indexed caller,
        address indexed blabs
    );

    event LogCrpImpl(
        address indexed caller,
        address indexed crpImpl
    );

    event LogExchproxy(
        address indexed caller,
        address indexed exchangeProxy
    );

    event LogPermissionmanager(
        address indexed caller,
        address indexed permissionManager
    );

    constructor(address _crpImpl) public {
        blabs = msg.sender;
        crpImpl = _crpImpl;
    }

    // Function declarations

    /**
     * @notice Create a new CRP
     * @dev emits a LogNewCRP event
     * @param factoryAddress - the BFactory instance used to create the underlying pool
     * @param poolParams - struct containing the names, tokens, weights, balances, and swap fee
     * @param rights - struct of permissions, configuring this CRP instance (see above for definitions)
     */
    function newCrp(
        address factoryAddress,
        PoolParams calldata poolParams,
        RightsManager.Rights calldata rights
    )
        external
        onlyAuthorized
        returns (CRPoolExtend)
    {
        require(poolParams.constituentTokens.length >= BalancerConstants.MIN_ASSET_LIMIT, "ERR_TOO_FEW_TOKENS");
        require(exchangeProxy != address(0), "ERR_EXCH_PROXY_NOT_INITIALIZED");
        require(permissionManager != address(0), "ERR_PERM_MAN_NOT_INITIALIZED");


        // Arrays must be parallel
        require(poolParams.tokenBalances.length == poolParams.constituentTokens.length, "ERR_START_BALANCES_MISMATCH");
        require(poolParams.tokenWeights.length == poolParams.constituentTokens.length, "ERR_START_WEIGHTS_MISMATCH");

        CRPoolExtend crp = new CRPoolExtend(
            crpImpl,
            exchangeProxy,
            abi.encodeWithSignature(
                "initialize(address,(string,string,address[],uint256[],uint256[],uint256),(bool,bool,bool,bool,bool,bool))",
                factoryAddress,
                poolParams,
                rights
            )
        );

        emit LogNewCrp(msg.sender, address(crp));

        _isCrp[address(crp)] = true;
        // The caller is the controller of the CRP
        // The CRP will be the controller of the underlying Core BPool
        //crp.setController(msg.sender);
        Address.functionDelegateCall(address(crp), abi.encodeWithSignature("setController(address)", msg.sender));

        address[] memory accounts = new address[](1);
        accounts[0] = address(crp);
        // assign permissions
        IPermissionManager(permissionManager).assignItem(2, accounts);
        IPermissionManager(permissionManager).assignItem(5, accounts);

        return crp;
    }

    function setBLabs(address b)
        external
    {
        require(msg.sender == blabs, "ERR_NOTBLABS");
        emit LogBlabs(msg.sender, b);
        blabs = b;
    }

    function setCrpImpl(address _crpImpl)
        external
    {
        require(msg.sender == blabs, "ERR_NOT_BLABS");
        emit LogCrpImpl(msg.sender, _crpImpl);
        crpImpl = _crpImpl;
    }

    function setExchProxy(address _exchProxy)
        external
    {
        require(msg.sender == blabs, "ERR_NOTBLABS");
        emit LogExchproxy(msg.sender, _exchProxy);
        exchangeProxy = _exchProxy;
    }

    function setPermissionManager(address _permissionManager)
        external
    {
        require(msg.sender == blabs, "ERR_NOTBLABS");
        emit LogPermissionmanager(msg.sender, _permissionManager);
        permissionManager = _permissionManager;
    }

    function setAuthorization(address _authorization)
        external
    {
        require(msg.sender == blabs, "ERR_NOTBLABS");
        _setAuthorization(_authorization);
    }

    /**
     * @notice Check to see if a given address is a CRP
     * @param addr - address to check
     * @return boolean indicating whether it is a CRP
     */
    function isCrp(address addr) external view returns (bool) {
        return _isCrp[addr];
    }
}
