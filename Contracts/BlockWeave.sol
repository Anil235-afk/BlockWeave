// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title DeFiLendingPlatform
 * @dev A decentralized lending platform with deposit, borrow, and repay functionality
 * @author Your Name
 */
contract DeFiLendingPlatform {
    
    // State variables
    mapping(address => uint256) public deposits;
    mapping(address => uint256) public borrowedAmounts;
    mapping(address => uint256) public lastBorrowTime;
    
    uint256 public constant INTEREST_RATE = 5; // 5% annual interest
    uint256 public constant COLLATERAL_RATIO = 150; // 150% collateralization required
    uint256 public totalDeposits;
    uint256 public totalBorrowed;
    
    address public owner;
    
    // Events
    event Deposited(address indexed user, uint256 amount);
    event Borrowed(address indexed user, uint256 amount);
    event Repaid(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier hasDeposit() {
        require(deposits[msg.sender] > 0, "No deposits found");
        _;
    }
    
    modifier hasBorrowed() {
        require(borrowedAmounts[msg.sender] > 0, "No borrowed amount found");
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    /**
     * @dev Core Function 1: Deposit ETH to earn interest
     * Users can deposit ETH which can be borrowed by others
     */
    function deposit() external payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        
        deposits[msg.sender] += msg.value;
        totalDeposits += msg.value;
        
        emit Deposited(msg.sender, msg.value);
    }
    
    /**
     * @dev Core Function 2: Borrow ETH against deposited collateral
     * Users can borrow up to 66% of their deposited amount (150% collateral ratio)
     */
    function borrow(uint256 _amount) external hasDeposit {
        require(_amount > 0, "Borrow amount must be greater than 0");
        
        // Calculate maximum borrowable amount (66% of deposit for 150% collateral ratio)
        uint256 maxBorrowable = (deposits[msg.sender] * 100) / COLLATERAL_RATIO;
        uint256 currentDebt = calculateDebtWithInterest(msg.sender);
        
        require(
            currentDebt + _amount <= maxBorrowable,
            "Exceeds borrowing limit based on collateral"
        );
        require(address(this).balance >= _amount, "Insufficient liquidity");
        
        // Update borrowed amount and timestamp
        borrowedAmounts[msg.sender] = currentDebt + _amount;
        lastBorrowTime[msg.sender] = block.timestamp;
        totalBorrowed += _amount;
        
        // Transfer borrowed amount to user
        payable(msg.sender).transfer(_amount);
        
        emit Borrowed(msg.sender, _amount);
    }
    
    /**
     * @dev Core Function 3: Repay borrowed amount with interest
     * Users repay their debt to unlock their collateral
     */
    function repay() external payable hasBorrowed {
        require(msg.value > 0, "Repay amount must be greater than 0");
        
        uint256 totalDebt = calculateDebtWithInterest(msg.sender);
        require(msg.value <= totalDebt, "Repayment exceeds debt");
        
        // Update borrowed amount
        borrowedAmounts[msg.sender] = totalDebt - msg.value;
        totalBorrowed -= msg.value;
        
        // Reset borrow time if fully repaid
        if (borrowedAmounts[msg.sender] == 0) {
            lastBorrowTime[msg.sender] = 0;
        } else {
            lastBorrowTime[msg.sender] = block.timestamp;
        }
        
        emit Repaid(msg.sender, msg.value);
    }
    
    /**
     * @dev Withdraw deposited ETH (only if no outstanding debt)
     */
    function withdraw(uint256 _amount) external hasDeposit {
        require(_amount > 0, "Withdrawal amount must be greater than 0");
        require(deposits[msg.sender] >= _amount, "Insufficient deposit balance");
        require(borrowedAmounts[msg.sender] == 0, "Outstanding debt must be repaid first");
        
        deposits[msg.sender] -= _amount;
        totalDeposits -= _amount;
        
        payable(msg.sender).transfer(_amount);
        
        emit Withdrawn(msg.sender, _amount);
    }
    
    /**
     * @dev Calculate debt with accrued interest
     * @param _user Address of the borrower
     * @return Total debt including interest
     */
    function calculateDebtWithInterest(address _user) public view returns (uint256) {
        if (borrowedAmounts[_user] == 0 || lastBorrowTime[_user] == 0) {
            return borrowedAmounts[_user];
        }
        
        uint256 timeElapsed = block.timestamp - lastBorrowTime[_user];
        uint256 annualInterest = (borrowedAmounts[_user] * INTEREST_RATE) / 100;
        uint256 interest = (annualInterest * timeElapsed) / 365 days;
        
        return borrowedAmounts[_user] + interest;
    }
    
    /**
     * @dev Get user's account information
     * @param _user Address of the user
     * @return depositAmount User's total deposits
     * @return borrowedAmount User's borrowed amount with interest
     * @return availableToBorrow Maximum amount user can still borrow
     */
    function getUserInfo(address _user) external view returns (
        uint256 depositAmount,
        uint256 borrowedAmount,
        uint256 availableToBorrow
    ) {
        depositAmount = deposits[_user];
        borrowedAmount = calculateDebtWithInterest(_user);
        
        if (depositAmount == 0) {
            availableToBorrow = 0;
        } else {
            uint256 maxBorrowable = (depositAmount * 100) / COLLATERAL_RATIO;
            availableToBorrow = maxBorrowable > borrowedAmount ? 
                               maxBorrowable - borrowedAmount : 0;
        }
    }
    
    /**
     * @dev Get platform statistics
     */
    function getPlatformInfo() external view returns (
        uint256 _totalDeposits,
        uint256 _totalBorrowed,
        uint256 _availableLiquidity
    ) {
        _totalDeposits = totalDeposits;
        _totalBorrowed = totalBorrowed;
        _availableLiquidity = address(this).balance;
    }
    
    /**
     * @dev Emergency withdrawal function for owner
     */
    function emergencyWithdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
    
    // Receive function to accept ETH
    receive() external payable {
        // Auto-deposit any ETH sent directly to contract
        deposits[msg.sender] += msg.value;
        totalDeposits += msg.value;
        emit Deposited(msg.sender, msg.value);
    }
}
