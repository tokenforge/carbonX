import {ethers} from "hardhat";
import {
    CarbonReceipt20,
    CarbonReceipt20__factory, CarbonReceipt55__factory, CarbonVault,
    CarbonVault__factory,
    CarbonX,
    CarbonX__factory
} from "../../typechain";
import {SignerWithAddress} from "@nomiclabs/hardhat-ethers/signers";
import {Contract, ContractFactory} from "ethers";

interface CreateContractsResult<CarbonReceipt extends Contract, CarbonReceiptFactory extends ContractFactory> {
    token: CarbonX,    
    receipt: CarbonReceipt,
    vault: CarbonVault,
}

export async function deployReceipt<CarbonReceipt extends Contract, CarbonReceiptFactory extends ContractFactory>(
    governance: SignerWithAddress, backend: SignerWithAddress,
    receiptContract: string,
): Promise<CarbonReceipt> {
    const carbonReceiptFactory = (await ethers.getContractFactory(receiptContract, governance)) as ContractFactory;
    const receipt = await carbonReceiptFactory.deploy('CarbonFarming1', 'CF1');
    await receipt.deployed();
    
    return receipt as CarbonReceipt;
}

export function isCarbonReceipt55<CarbonReceiptFactory>(
    factory: any
): factory is CarbonReceipt55__factory {
    console.log('isCarbonReceipt55', factory)
    console.log('.-', factory instanceof CarbonReceipt55__factory)
    return factory instanceof CarbonReceipt55__factory;
}

export async function createContracts<CarbonReceipt extends Contract, CarbonReceiptFactory extends ContractFactory>(
    governance: SignerWithAddress, backend: SignerWithAddress,
    receiptContract: string, args: Array<any>
): Promise<{ receipt: CarbonReceipt; vault: CarbonVault; token: CarbonX }>
{
    const tokenFactory = (await ethers.getContractFactory('CarbonX', governance)) as CarbonX__factory;
    const token = await tokenFactory.deploy(backend.address, 'ipfs://');
    await token.deployed();

    const carbonReceiptFactory = (await ethers.getContractFactory(receiptContract, governance)) as ContractFactory;
    
    const receipt = await carbonReceiptFactory.deploy('AAA', 'A1');
    await receipt.deployed();

    const vaultFactory = (await ethers.getContractFactory('CarbonVault', governance)) as CarbonVault__factory;

    const vault = await vaultFactory.deploy(receipt.address, token.address);
    await vault.deployed();

    // Vault becomes MinterRole in Receipt Token
    await receipt.grantRole(await receipt.MINTER_ROLE(), vault.address);
    
    return {
        token,
        receipt: receipt as CarbonReceipt,
        vault
    }
}
