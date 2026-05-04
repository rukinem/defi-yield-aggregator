// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract YieldAggregator is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct Strategy {
        address vault;
        address want;
        uint256 totalDeposited;
        uint256 performanceFee;
        uint256 withdrawalFee;
        bool isActive;
        uint256 totalShares;
    }

    mapping(address => Strategy) public strategies;
    mapping(address => mapping(address => uint256)) public userShares;
    address[] public strategyList;

    event Deposited(address indexed user, address indexed strategy, uint256 amount, uint256 shares);
    event Withdrawn(address indexed user, address indexed strategy, uint256 amount, uint256 shares);

    constructor() Ownable(msg.sender) {}

    function addStrategy(address _strategy, address _want, uint256 _perfFee, uint256 _withdrawFee) external onlyOwner {
        strategies[_strategy] = Strategy(_strategy, _want, 0, _perfFee, _withdrawFee, true, 0);
        strategyList.push(_strategy);
    }

    function deposit(address _strategy, uint256 _amount) external nonReentrant {
        Strategy storage strat = strategies[_strategy];
        require(strat.isActive, "Not active");
        uint256 shares = strat.totalShares == 0 ? _amount : (_amount * strat.totalShares) / strat.totalDeposited;
        IERC20(strat.want).safeTransferFrom(msg.sender, address(this), _amount);
        strat.totalDeposited += _amount;
        strat.totalShares += shares;
        userShares[_strategy][msg.sender] += shares;
        emit Deposited(msg.sender, _strategy, _amount, shares);
    }

    function withdraw(address _strategy, uint256 _shares) external nonReentrant {
        Strategy storage strat = strategies[_strategy];
        require(userShares[_strategy][msg.sender] >= _shares, "Insufficient shares");
        uint256 amount = (_shares * strat.totalDeposited) / strat.totalShares;
        uint256 fee = (amount * strat.withdrawalFee) / 10000;
        userShares[_strategy][msg.sender] -= _shares;
        strat.totalShares -= _shares;
        strat.totalDeposited -= amount;
        IERC20(strat.want).safeTransfer(msg.sender, amount - fee);
        emit Withdrawn(msg.sender, _strategy, amount - fee, _shares);
    }

    function getPricePerShare(address _strategy) external view returns (uint256) {
        Strategy storage strat = strategies[_strategy];
        return strat.totalShares == 0 ? 1e18 : (strat.totalDeposited * 1e18) / strat.totalShares;
    }
}