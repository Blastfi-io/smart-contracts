
# IGNITING BLAST

At BlastFi, we're committed to unlocking the full potential of blockchain technology, providing a platform for visionary developers and investors to collaborate and propel the blast chain forward.



## Blast Features usage in staking contract

```solidity
IBlast public constant BLAST = IBlast(0x4300000000000000000000000000000000000002);
address public gasRedeemer;

function claimMyContractsGas() external {
    require(gasRedeemer == _msgSender(),"No access to redeem gas");
    BLAST.claimAllGas(address(this), gasRedeemer);
}
```


## Demo

Staking is live on Blast testnset:


[0x148E9623938231b783e12DCbA356f5Bb05D0e2Da](https://testnet.blastscan.io/address/0xbe96188F78242B595E94E03e0810EEfA76BD5309)
## Documentation

[Documentation](https://blastfi.mintlify.app/)


## License


[![MIT License](https://img.shields.io/badge/License-MIT-green.svg)](https://choosealicense.com/licenses/mit/)
[![GPLv3 License](https://img.shields.io/badge/License-GPL%20v3-yellow.svg)](https://opensource.org/licenses/)
[![AGPL License](https://img.shields.io/badge/license-AGPL-blue.svg)](http://www.gnu.org/licenses/agpl-3.0)

