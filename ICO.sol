pragma solidity ^0.4.24;

/**
 * SP8 Token ICO
 */
 
import "./TokenERC20.sol";

/**
 * @title Safe maths
 */
library SafeMath {
    function add(uint a, uint b) internal pure returns (uint c) {
        c = a + b;
        require(c >= a);
    }
    function sub(uint a, uint b) internal pure returns (uint c) {
        require(b <= a);
        c = a - b;
    }
    function mul(uint a, uint b) internal pure returns (uint c) {
        c = a * b;
        require(a == 0 || c / a == b);
    }
    function div(uint a, uint b) internal pure returns (uint c) {
        require(b > 0);
        c = a / b;
    }
}


contract ICOPhase {
    uint256 public presaleTimeFrom = 1529514000;//0h 21/06/2018 GMT
    uint256 public presaleTimeTo = 1532106000;//0h 21/07/2018 GMT

    uint256 public publicSaleTime1From = 1533056400;//0h 01/08/2018 GMT
    uint256 public publicSaleTime1To = 1533834000;//0h 10/08/2018 GMT
    uint256 public publicSaleTime2From = 1533920400;//0h 11/08/2018 GMT
    uint256 public publicSaleTime2To = 1534698000;//0h 20/08/2018 GMT
    uint256 public publicSaleTime3From = 1534784400;//0h 21/08/2018 GMT
    uint256 public publicSaleTime3To = 1535562000;//0h 30/08/2018 GMT
    
    uint256 public presaleToken = 200000000;
    uint256 public publicSaleToken = 500000000;
}


contract SP8TokenICO is Owned, ICOPhase {
    using SafeMath for uint256;
    
    struct Buyer {
        uint256 totalEth; // total eth of investor to buy token
        uint256 totalTokens; // total token of investor
    }
    
    TokenERC20 private BasicToken;
    address public receiverEth; // The address receive ether
    uint256 public exchangeRate = 38417; // 1 ETH = 38417 
    uint256 public decimals = 18;
    address public ownerToken;
    uint256 public minSaleToken = 300000000;
    uint256 public presaleTokenSold;
    uint256 public publicSaleTokenSold;
    
    mapping (address => bool) public whitelist;
    mapping (address => Buyer) buyers;  // list buyers
    
    modifier onlyWallet() {
        require(msg.sender == receiverEth);
        _;
    }
    
    constructor(address _tokenAddress, address _receiverEth) payable public {
        receiverEth = _receiverEth;
        BasicToken = TokenERC20(_tokenAddress);
        decimals = BasicToken.decimals();
        ownerToken = BasicToken.owner();
        whitelist[msg.sender]= true;
    }
    
    /**
     * @dev fallback function when receive ether
     */
	function () payable public {
	    require(whitelist[msg.sender]);
	    buy();
	}
	
	function buy() payable public {
	    require(exchangeRate > 0);
        require(msg.sender != 0x0);
        require(msg.value != 0);
        
        uint256 eth = msg.value;
        uint256 amount;
        
        if (presaleTimeFrom <= now && now <= presaleTimeTo && presaleTokenSold < presaleToken) {
            amount = calculatorToken(eth, presaleTokenSold, presaleToken, 0);
            presaleTokenSold.add(amount);
        } else if (publicSaleTime1From <= now && now <= publicSaleTime1To && publicSaleTokenSold < publicSaleToken) { 
            amount = calculatorToken(eth, publicSaleTokenSold, publicSaleToken, 20);
            publicSaleTokenSold.add(amount);
        } else if (publicSaleTime2From <= now && now <= publicSaleTime2To && publicSaleTokenSold < publicSaleToken) {
            amount = calculatorToken(eth, publicSaleTokenSold, publicSaleToken, 15);
            publicSaleTokenSold.add(amount);
        } else if (publicSaleTime3From <= now && now <= publicSaleTime3To && publicSaleTokenSold < publicSaleToken) {  
            amount = calculatorToken(eth, publicSaleTokenSold, publicSaleToken, 10);
            publicSaleTokenSold.add(amount);
        } else {
            revert();
        }
        
        buyers[msg.sender].totalEth = buyers[msg.sender].totalEth.add(eth);
        buyers[msg.sender].totalTokens = buyers[msg.sender].totalTokens.add(amount);
        receiverEth.transfer(eth);
	}
	
	/**
	 * @dev Calculator Token
	 * @param _eth ETH received
	 * @param _saleTokenSold The token was sold
	 * @param _saleToken Maximum token sell
	 * @param _bonus Percent of bonus
	 * @return _amount The total payment tokens for the buyer
	 */
	function calculatorToken(
	    uint256 _eth, 
	    uint256 _saleTokenSold, 
	    uint256 _saleToken, 
	    uint256 _bonus
    ) internal view returns (uint256 _amount) {
    	uint256 _subAmount = _eth.div(1 ether).mul(exchangeRate*10**decimals); 
    	_amount = _subAmount.mul(_bonus).div(100).add(_subAmount);
    	require(_saleTokenSold.add(_amount) <= _saleToken);
	}
    
    /**
	 * @dev Payment ETH
	 */
	function payEth(address _recipient) onlyOwner public returns(bool){
	    require(_recipient != 0x0);
	    require(now > publicSaleTime3To);
	    require(presaleTokenSold.add(publicSaleTokenSold) >= minSaleToken);
	    BasicToken.transferFrom(ownerToken, _recipient, buyers[_recipient].totalTokens); 
	    buyers[_recipient].totalEth = 0;
	    buyers[_recipient].totalTokens == 0;
	    return true;
	}
	
	/**
	 * @dev Refund ETH
	 */
	function refundEth(address _recipient) onlyWallet public payable returns(bool){
	    require(_recipient != 0x0);
	    require(now > publicSaleTime3To);
	    require(presaleTokenSold.add(publicSaleTokenSold) < minSaleToken);
	    require(buyers[_recipient].totalEth == msg.value);
	    buyers[_recipient].totalEth = 0;
	    buyers[_recipient].totalTokens == 0;
	    _recipient.transfer(msg.value);
	    return true;
	}
	
    /**
	 * @dev Allows to add a new member.
	 * @param member Address of new member.
	 */
    function addWhitelist(address member) public onlyOwner {
        require (member != 0x0);
        require(!whitelist[member]);
        whitelist[member] = true;
    }
    
    function addMultiAddressWhitelist(address[] members) public onlyOwner {
        for (uint i=0; i<members.length; i++) {
            if (members[i] != 0x0 && !whitelist[members[i]]) {
                whitelist[members[i]] = true;
            }
        }
    }
    
    /**
     * @dev Allows to remove an member.
     * @param member Address of member.
     */
    function removeWhitelist(address member) public onlyOwner {
       require(whitelist[member]);
       whitelist[member] = false;
    }
    
    /**
     * @dev Allows to replace an owner with a new owner.
     * @param member Address of member to be replaced.
     * @param newMember Address of new member.
     */
    function replaceWhitelist(address member, address newMember) public onlyOwner {
        require (newMember != 0x0);
        if (whitelist[member]) {
            whitelist[member] = false;
            whitelist[newMember] = true;
        } else {
            whitelist[newMember] = false;
        }
        //emit MemberRemoval(member);
        //emit MemberAddition(newMember);
    }
    
    /**
     * @dev Set exchange rate of ETH with Token 
     */
    function setExchangeRate(uint256 _exchangeRate) onlyOwner public returns(bool){
        require(_exchangeRate > 0);
        exchangeRate = _exchangeRate;
    }
    
    /**
     * @dev Get exchange rate
     */ 
    function getExchangeRate() public view returns(uint256) {
        return exchangeRate;
    }
    
    /**
     * @dev Set address receiver ether
     * @param _receiverEth The address receiver ether
     */
	function setReceiverEth(address _receiverEth) onlyWallet public returns(bool) {
	    require(_receiverEth != 0x0);
	    require(_receiverEth != receiverEth);
	    receiverEth = _receiverEth;
	    return true;
	}
	
	/**
	 * @dev Get info current phase ICO
	 * @return return (Phase, PresaleTokenSold, PublicSaleTokenSold)
	 */
	function getCurrentPhaseICO() public view returns(uint8, uint256, uint256) {
	    uint8 _phase = 0;
	    if (presaleTimeFrom <= now && now <= presaleTimeTo) {
            _phase = 1;
        } else if (publicSaleTime1From <= now && now <= publicSaleTime1To) { 
            _phase = 2;
        } else if (publicSaleTime2From <= now && now <= publicSaleTime2To) {  
            _phase = 3;
        } else if (publicSaleTime3From <= now && now <= publicSaleTime3To) {  
            _phase = 4;
        }
        
        return(_phase, presaleTokenSold, publicSaleTokenSold);
	}

}

