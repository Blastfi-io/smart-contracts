// solhint-disable not-rely-on-time
pragma solidity ^0.8.3;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";


interface IBlast {
  // Note: the full interface for IBlast can be found below
  function configureClaimableGas() external;
  function claimAllGas(address contractAddress, address recipient) external returns (uint256);
}


contract StakingReward is  ReentrancyGuardUpgradeable,OwnableUpgradeable,AccessControlUpgradeable {
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    IBlast public constant BLAST = IBlast(0x4300000000000000000000000000000000000002);
    

    struct TierStakers{
        EnumerableSetUpgradeable.AddressSet tier_stakers;
    }

    /* ========== STATE VARIABLES ========== */
    IERC20Upgradeable public stakingToken;
    uint256 public _totalSupply;
    address public gasRedeemer;
    
    mapping(address => mapping(uint256 => uint256)) public userLastStackedTime;
    mapping(address => uint256) public _balances;
    mapping(address => mapping(uint256 => uint256)) public _balancesTier;
    mapping(uint256 => uint256) public lockRate;
    mapping(uint256 => uint256) public supply;
    mapping(uint256 => TierStakers) private stakers;

    

    /* ========== Initialize ========== */

    function initialize(address _stakingToken) public initializer{
         stakingToken = IERC20Upgradeable(_stakingToken);

         BLAST.configureClaimableGas(); 
         __Ownable_init();
         __ReentrancyGuard_init();
         __AccessControl_init();
    }

    /* ========== VIEWS ========== */

    function totalSupply() external view  returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view  returns (uint256) {
        return _balances[account];
    }

    function balanceTierOf(address account,uint256 time) public view  returns (uint256) {
        return _balancesTier[account][time];
    }

    function earned(address account,uint256 time) public view  returns (uint256) {
        return _balancesTier[account][time].mul(lockRate[time]).div(10**4);
    }


    /* ========== MUTATIVE FUNCTIONS ========== */

    function _afterStaking(address sender,  uint256 _time) internal {
        if(_balancesTier[sender][_time] >= 0) stakers[_time].tier_stakers.add(sender); else stakers[_time].tier_stakers.remove(sender);
    }

    function _staking(address sender,uint256 amount,uint256 time) private {
        _totalSupply = _totalSupply.add(amount);
        supply[time] = supply[time].add(amount);

        _balances[sender] = _balances[sender].add(amount);
        _balancesTier[sender][time] = _balancesTier[sender][time].add(amount);

        userLastStackedTime[sender][time] = block.timestamp;

        _afterStaking(sender,time);
    }

    function _exit(address sender,uint256 time) private returns (uint256) {
        uint256 stakedTime = block.timestamp.sub(userLastStackedTime[sender][time]);
        uint256 _balanceTier =  _balancesTier[sender][time];
    
        require(stakedTime > time, "Withdraw locked");
        require(_balanceTier > 0, "Balance is 0");

        uint256 amount = _balanceTier.add(earned(sender,time));

        _totalSupply = _totalSupply.sub(_balanceTier);
        supply[time] = supply[time].sub(_balanceTier);

        _balances[sender] = _balances[sender].sub(_balanceTier);
        _balancesTier[sender][time] = 0;

        _afterStaking(sender,time);

        return amount;
    }


    function stake(uint256 amount,uint256 time) external  nonReentrant  {
        require(amount > 0, "Cannot stake 0");

        
        _staking(_msgSender(),amount,time);
        stakingToken.safeTransferFrom(_msgSender(), address(this), amount);

      
        emit Staked(_msgSender(), amount);
    }

     
    function exit(uint256 time) external  nonReentrant  {
        
        uint256 amount = _exit(_msgSender(),time);
        stakingToken.safeTransfer(_msgSender(),amount);

        
        emit Withdrawn(_msgSender(), amount);
    }

    function reset(uint256 time) external  nonReentrant  {
        uint256 stakedTime = block.timestamp.sub(userLastStackedTime[_msgSender()][time]);
        uint256 amount =  earned(_msgSender(),time);

        require(stakedTime > time, "Reset locked");
        require(amount > 0, "Balance is 0");

        _totalSupply = _totalSupply.add(amount);
        supply[time] = supply[time].add(amount);

        _balances[_msgSender()] = _balances[_msgSender()].add(amount);
        _balancesTier[_msgSender()][time] = _balancesTier[_msgSender()][time].add(amount);

        userLastStackedTime[_msgSender()][time] = block.timestamp;
    }

    function migrate(uint256 time,uint256 toTime) external  nonReentrant  {
        uint256 amount = _exit(_msgSender(),time);
        _staking(_msgSender(),amount,toTime);
    }

    function holders(uint256 _time) public view returns (uint256) {
        return stakers[_time].tier_stakers.length();
    }



    function balanceOfHolders(uint256 startIndex, uint256 count,uint256 _time) public view returns (address[] memory, uint256[] memory) {
        
        address[] memory addressList;
        uint256[] memory balanceList;

        EnumerableSetUpgradeable.AddressSet storage _holders = stakers[_time].tier_stakers;

        
        if(_holders.length() > 0 && startIndex < _holders.length()) {
            
            if(_holders.length().sub(startIndex) < count)
                count = _holders.length().sub(startIndex);
            
            addressList = new address[](count);
            balanceList = new uint256[](count);
        
            for (uint256 i = 0; i < count; i++) {
                
                addressList[i] = _holders.at(startIndex.add(i));
                balanceList[i] = balanceTierOf(addressList[i],_time);
                
            }
            
        }

        return (addressList,balanceList);
        
    }

    function claimMyContractsGas() external {
        require(gasRedeemer == _msgSender(),"you don't have access to redeem gas");
        BLAST.claimAllGas(address(this), gasRedeemer);
    }


    /* ========== RESTRICTED FUNCTIONS ========== */

    function updateLockRate(uint256 _lockedTime,uint256 _rewardRate) external onlyAdmins{
        lockRate[_lockedTime] = _rewardRate;
    }

    function setGasRedeemer(address _gasRedeemer) external onlyAdmins{
        gasRedeemer = _gasRedeemer;
    }



    // Added to support recovering LP Rewards from other systems such as BAL to be distributed to holders
    function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyAdmins {
        IERC20Upgradeable(tokenAddress).safeTransfer(owner(), tokenAmount);
        emit Recovered(tokenAddress, tokenAmount);
    }
    

    function addAdminRole(address admin) public onlyOwner {
        _setupRole(ADMIN_ROLE, admin);
    }

    function revokeAdminRole(address admin) public onlyAdmins {
        revokeRole(ADMIN_ROLE, admin);
    }

    function adminRole(address admin) public view returns (bool) {
        return hasRole(ADMIN_ROLE, admin);
    }

    modifier onlyAdmins() {
        require(
            hasRole(ADMIN_ROLE, _msgSender()) || owner() == _msgSender(),
            "You don't have permission"
        );
        _;
    }

    

    /* ========== EVENTS ========== */

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event Recovered(address token, uint256 amount);
}
