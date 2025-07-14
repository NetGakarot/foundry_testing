// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title DSCEngine
 *     @author Gakarot
 *
 *     This system is designed to be as minimal as possible, and have the token maintain
 *     a 1 token == 1$ peg.
 *     This stablecoin has the properties:
 *     -Exogenous Collateral
 *     -Dollar Pegged
 *     -Algorithmically Stable
 *
 *     It is similar to DAI had no governance, no fees, and was only backed by WETH and
 *     WBTC.
 *
 *     @notice This contract is the core of the DSC system. It handles all the logic for
 *     mining and redeeming DSC, as well as depositing & withdrawing collateral.
 *     @notice This contract is very loosely based on the MakerDAI DSS (DAI) system.
 */
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract DSCEngine is ReentrancyGuard, Ownable {
    ////////////////////
    //    Errors      //
    ////////////////////

    error DSCEngine_NeedsMoreThanZero();
    error DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
    error DSCEngine__TokenNotAllowed(address token);
    error DSCEngine_TransferFailed();
    error DSCEngine_BreaksHealthFactor(uint256 healthFactor);
    error DSCEngine_MintFailed();
    error DSCEngine_healthFactorOk();
    error DSCEngine_HealthFactorNotImproved();
    error DSCEngine_LiquidatorDscBalanceLow();
    error DSCEngine_InsufficientCollateral();

    ////////////////////
    // State Variables //
    ////////////////////

    DecentralizedStableCoin immutable i_Dsc;

    uint256 private constant LIQUIDATION_THRESHOLD = 50; // This means you need to be 200% over-collateralized
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant MIN_HEALTH_FACTOR = 1.1e18;
    uint256 private constant LIQUIDATION_BONUS = 10; // This means you get assets at a 10% discount when liquidating

    /// @dev Mapping of token address to price feed address
    mapping(address => address priceFeed) private s_priceFeeds;

    /// @dev Amount of collateral deposited by user
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;

    /// @dev Amount of DSC minted by user
    mapping(address user => uint256 amountDscMinted) private s_DSCMinted;

    /// @dev If we know exactly how many tokens we have, we could make this immutable!
    address[] private s_collateralTokens;

    ////////////////////
    //    Events      //
    ////////////////////

    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);

    event CollateralRedeemed(
        address indexed redeemedFrom, address indexed redeemedTo, address indexed token, uint256 amount
    );

    event FullLiquidation(address indexed user, address indexed collateral, uint256 amount);
    event PartialLiquidation(address indexed user, address indexed collateral, uint256 amount);
    event IncentiveOnlyLiquidation(address indexed user, address indexed collateral, uint256 amount);

    ////////////////////
    //    Modifiers   //
    ////////////////////

    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine_NeedsMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert DSCEngine__TokenNotAllowed(token);
        }
        _;
    }

    ////////////////
    //  Functions //
    ////////////////

    constructor(
        address[] memory tokenAddresses,
        address[] memory priceFeedAddresses,
        address DscAddress,
        address _owner
    ) Ownable(_owner) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
        }

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }

        i_Dsc = DecentralizedStableCoin(DscAddress);
    }

    ///////////////////////
    // External Functions//
    //////////////////////

    /**
     * @param tokenCollateralAddress The address of the token to deposit as collateral
     * @param amountCollateral The amount of collateral to deposit.
     * @param amountDscToMint The amount of decentralized stablecoin to mint
     * @notice This function will deposit your collateral and mint DSC in one tx.
     */
    function depositCollateralAndMintDsc(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDscToMint
    ) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintDsc(amountDscToMint);
    }

    /**
     * @notice follows CEI pattern
     * @param tokenCollateralAddress The address of the token to deposit as collateral
     * @param amountCollateral The amount of collateral to deposit
     */

    /**
     * @param tokenCollateralAddress The collateral address to redeem
     * @param amountCollateral The amount of collateral to burn
     * @param amountDscToBurn The amount of DSC to burn
     * @notice This function burn DSC and redeem underlying collateral in one tx.
     */
    function redeemCollateralForDsc(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountDscToBurn)
        external
    {
        _burnDsc(amountDscToBurn, msg.sender, msg.sender);
        _redeemCollateral(msg.sender, msg.sender, tokenCollateralAddress, amountCollateral);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        external
        moreThanZero(amountCollateral)
        nonReentrant
    {
        _redeemCollateral(msg.sender, msg.sender, tokenCollateralAddress, amountCollateral);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function burnDsc(uint256 amount) external moreThanZero(amount) {
        _burnDsc(amount, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @notice Liquidates a user whose health factor has fallen below the minimum threshold.
     * @dev This function burns DSC from the liquidator and seizes equivalent collateral from the user,
     *      along with a liquidation bonus. It supports users holding multiple collateral tokens.
     *
     * Three cases are handled:
     * 1. If collateral value is enough to cover full debt + 10% bonus, full liquidation is done with full bonus.
     * 2. If collateral value can cover full debt but not full bonus, partial bonus (whatever is left) is given.
     * 3. If collateral is insufficient to even cover full debt, burn DSC equal to what’s coverable with remaining collateral,
     *    and give a small 0.5% bonus.
     *
     * Steps:
     * - Checks if the user's health factor is below the required threshold.
     * - Calculates actual DSC to burn based on user's debt and available collateral.
     * - Burns DSC from the liquidator and reduces user's minted DSC accordingly.
     * - Calculates the USD value of collateral to seize based on actual DSC burned and applicable bonus.
     * - Iterates over all collateral tokens deposited by the user:
     *      - Transfers just enough collateral tokens (by USD value) to match the required amount.
     *      - Proceeds across multiple tokens if necessary.
     * - Reverts if the liquidation did not improve the user's health factor.
     *
     * @param user The account being liquidated.
     * @param debtToCover The amount of DSC (in wei) that the liquidator is offering to burn.
     *
     * Requirements:
     * - User's health factor must be below the minimum threshold.
     * - Liquidator must have at least `debtToCover` amount of DSC.
     *
     * Emits:
     * - `FullLiquidation` events for each collateral token seized.
     */
    function liquidate(address user, uint256 debtToCover) external moreThanZero(debtToCover) nonReentrant {
        if (_healthFactor(user) >= MIN_HEALTH_FACTOR) revert DSCEngine_healthFactorOk();
        if (getAccountCollateralValue(user) == 0) revert DSCEngine_InsufficientCollateral();
        if (i_Dsc.balanceOf(msg.sender) < debtToCover) revert DSCEngine_LiquidatorDscBalanceLow();

        uint256 previousHealthFactor = _healthFactor(user);
        uint256 userDebt = s_DSCMinted[user];
        uint256 userCollateralUsd = getAccountCollateralValue(user);

        uint256 actualDscToBurn;
        uint256 bonusPct;

        if (userCollateralUsd >= debtToCover + ((debtToCover * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION)) {
            // Full bonus case
            actualDscToBurn = _min(debtToCover, userDebt);
            bonusPct = LIQUIDATION_BONUS;
        } else if (userCollateralUsd >= userDebt) {
            // Enough to cover full debt, but not bonus
            actualDscToBurn = userDebt;
            bonusPct = ((userCollateralUsd - userDebt) * LIQUIDATION_PRECISION) / userDebt;
        } else {
            // Not enough even for full debt: burn as much as possible, give 0.5% bonus on collateral
            actualDscToBurn = (userCollateralUsd * LIQUIDATION_PRECISION) / (LIQUIDATION_PRECISION + 50); // 0.5% bonus
            bonusPct = 50; // 0.5%
        }

        i_Dsc.burnFrom(msg.sender, actualDscToBurn);
        s_DSCMinted[user] -= actualDscToBurn;

        uint256 totalUsdToSeize = (actualDscToBurn * (LIQUIDATION_PRECISION + bonusPct)) / LIQUIDATION_PRECISION;
        require(totalUsdToSeize > 0, "Nothing to seize");
        _seizeUserCollateral(user, totalUsdToSeize);

        uint256 newHealthFactor = _healthFactor(user);

        bool didFullyRepay = s_DSCMinted[user] == 0;

        // Only require health factor improvement if it's a full liquidation
        if (didFullyRepay && newHealthFactor <= previousHealthFactor) {
            revert DSCEngine_HealthFactorNotImproved();
        }
    }

    function _min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }

    function _seizeUserCollateral(address user, uint256 usdToSeize) private {
        for (uint256 i = 0; i < s_collateralTokens.length && usdToSeize > 0; i++) {
            address token = s_collateralTokens[i];
            uint256 tokenBalance = s_collateralDeposited[user][token];
            if (tokenBalance == 0) continue;

            uint256 tokenUsdValue = _getUsdValue(token, tokenBalance);
            uint256 usdSeizable = _min(tokenUsdValue, usdToSeize);
            uint256 tokenAmountToSeize = getTokenAmountFromUsd(token, usdSeizable);

            if (tokenAmountToSeize > tokenBalance) {
                tokenAmountToSeize = tokenBalance;
            }

            s_collateralDeposited[user][token] -= tokenAmountToSeize;

            bool success = IERC20(token).transfer(msg.sender, tokenAmountToSeize);
            require(success, "Transfer failed");

            emit FullLiquidation(user, token, tokenAmountToSeize);

            usdToSeize -= _getUsdValue(token, tokenAmountToSeize);
        }
    }

    //////////////////////
    // Public Functions//
    ////////////////////

    function mintDsc(uint256 amountDscToMint) public moreThanZero(amountDscToMint) nonReentrant {
        s_DSCMinted[msg.sender] += amountDscToMint;

        _revertIfHealthFactorIsBroken(msg.sender);
        _mint(amountDscToMint);
    }

    function _mint(uint256 amountDscToMint) private {
        bool minted = i_Dsc.mint(msg.sender, amountDscToMint);
        if (!minted) {
            revert DSCEngine_MintFailed();
        }
    }

    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert DSCEngine_TransferFailed();
        }
    }

    function withdrawProtocolCollateral(address token) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        require(balance > 0, "No collateral to withdraw");

        bool success = IERC20(token).transfer(msg.sender, balance);
        require(success, "Transfer failed");
    }

    ////////////////////////
    // Private Functions //
    //////////////////////

    /**
     * @dev Low-Level internal function, do not call unless the function calling it is
     * checking for health factor being broken.
     */
    function _burnDsc(uint256 amountDscToBurn, address onBehalfOf, address dscFrom) private {
        s_DSCMinted[onBehalfOf] -= amountDscToBurn;
        bool success = i_Dsc.transferFrom(dscFrom, address(this), amountDscToBurn);
        if (!success) {
            revert DSCEngine_TransferFailed();
        }
        i_Dsc.burn(amountDscToBurn);
    }

    function _redeemCollateral(address from, address to, address tokenCollateralAddress, uint256 amountCollateral)
        private
    {
        s_collateralDeposited[from][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(from, to, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transfer(to, amountCollateral);
        if (!success) {
            revert DSCEngine_TransferFailed();
        }
    }

    //////////////////////////////////////////////
    // Private & Internal View & Pure Functions //
    /////////////////////////////////////////////

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        totalDscMinted = s_DSCMinted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
    }

    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
        return _calculateHealthFactor(totalDscMinted, collateralValueInUsd);
    }

    function _getUsdValue(address token, uint256 amount) private view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        uint8 feedDecimals = priceFeed.decimals();
        return ((uint256(price) * (10 ** (18 - feedDecimals))) * amount) / 1e18;
    }

    function _calculateHealthFactor(uint256 totalDscMinted, uint256 collateralValueInUsd)
        internal
        pure
        returns (uint256)
    {
        if (totalDscMinted == 0) return type(uint256).max;
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine_BreaksHealthFactor(userHealthFactor);
        }
    }

    /////////////////////////////////////////////
    // Public & External View & Pure Functions //
    ////////////////////////////////////////////

    function calculateHealthFactor(uint256 totalDscMinted, uint256 collateralValueInUsd)
        external
        pure
        returns (uint256)
    {
        return _calculateHealthFactor(totalDscMinted, collateralValueInUsd);
    }

    function getAccountInformation(address user)
        external
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        return _getAccountInformation(user);
    }

    function getUsdValue(
        address token,
        uint256 amount // in WEI
    ) external view returns (uint256) {
        return _getUsdValue(token, amount);
    }

    function getCollateralBalanceOfUser(address user, address token) external view returns (uint256) {
        return s_collateralDeposited[user][token];
    }

    function getTokenAmountFromUsd(address token, uint256 usdAmountInWei) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();

        uint8 feedDecimals = priceFeed.decimals();
        return (usdAmountInWei * 1e18) / (uint256(price) * (10 ** (18 - feedDecimals)));
    }

    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUsd) {
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];

            totalCollateralValueInUsd += _getUsdValue(token, amount);
        }
    }

    function getHealthFactor(address user) external view returns (uint256) {
        return _healthFactor(user);
    }

    function getCollateralTokenPriceFeed(address token) external view returns (address) {
        return s_priceFeeds[token];
    }

    function getDsc() external view returns (address) {
        return address(i_Dsc);
    }

    function getCollateralTokens() external view returns (address[] memory) {
        return s_collateralTokens;
    }

    function getMinHealthFactor() external pure returns (uint256) {
        return MIN_HEALTH_FACTOR;
    }

    function getLiquidationPrecision() external pure returns (uint256) {
        return LIQUIDATION_PRECISION;
    }

    function getLiquidationThreshold() external pure returns (uint256) {
        return LIQUIDATION_THRESHOLD;
    }

    function getLiquidationBonus() external pure returns (uint256) {
        return LIQUIDATION_BONUS;
    }

    function getPrecision() external pure returns (uint256) {
        return PRECISION;
    }

    function getProtocolCollateralBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
}
