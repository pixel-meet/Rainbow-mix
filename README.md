# RainbowMix - ERC404 extension to act as a tokenized NFT aggregator / Pool

## Introduction
Rainbow Mix (RBM) is a pioneering ERC404 extension that merges the excitement of NFT collections with the liquidity and accessibility of ERC20 tokens. At its core, RBM is a vibrant ecosystem that encapsulates a curated mix of existing NFT collections. This innovative approach offers participants a unique opportunity to own a piece of a diverse and valuable NFT portfolio through the simplicity of an ERC20 token transaction.

## Concept
Rainbow Mix is designed to democratize access to a variety of sought-after NFT collections, making it easier for enthusiasts to participate in the NFT market without navigating the complexities of individual NFT acquisitions. Each RBM token is intricately linked to a specific token ID within the Rainbow Mix collection, which could potentially be any NFT from the aggregated collections.

## Key Features
Diverse NFT Collection: Rainbow Mix aggregates NFTs from multiple renowned Ethereum NFT collections, offering a rich tapestry of digital art and assets.
Token-Linked NFTs: Each purchase of an RBM token is directly tied to a unique token ID within the Rainbow Mix collection. This token ID represents a chance to own one of the NFTs from the aggregated collections.
Dynamic Collection: The Rainbow Mix collection aims to reach a milestone of 10,000 NFTs. Until this cap is reached, new NFTs will be continually added to the collection, enhancing its diversity and value.
Holding Incentive: Token holders are encouraged to hold onto their RBM tokens if their associated token ID has not yet been allocated an NFT. As the collection grows, the probability of each unallocated token ID being linked to a new NFT increases, adding excitement and anticipation to the holding experience.
Mechanism

## Transfer rewards

Rainbow Mix enhances its ecosystem by introducing a transfer rewards system, incentivizing users to contribute NFTs to the collection. This system rewards users with RBM tokens for every NFT transferred into the Rainbow Mix contract, based on predetermined criteria. The rewards aim to encourage the growth of the collection and foster user engagement, while a cap on total rewards ensures the sustainability of the incentive mechanism. Through this approach, Rainbow Mix aims to build a diverse and valuable NFT portfolio, benefiting both contributors and token holders.


## Token Purchase: 
Investors buy RBM tokens, with each token representing a stake in the Rainbow Mix NFT collection.
Token-NFT Linkage: The underlying smart contract assigns each RBM token a unique token ID that has the potential to be linked to one of the NFTs in the Rainbow Mix collection.
### Collection Growth: 
New NFTs are periodically added to the Rainbow Mix collection until the total count reaches 10,000.
NFT Allocation: As NFTs are added, RBM tokens with previously unassigned token IDs are randomly selected to be linked to these new additions, rewarding patient holders.
Benefits
### Accessibility:
RBM lowers the barrier to entry for NFT enthusiasts, allowing for fractional ownership and investment in high-value NFTs.
Diversification: By holding RBM tokens, investors gain exposure to a broad range of NFT assets, mitigating the risk associated with investing in single NFTs.

### Liquidity: 
RBM tokens offer enhanced liquidity compared to traditional NFTs, enabling holders to buy and sell tokens more freely on ERC20-compatible exchanges.
Dynamic Ownership: The continually evolving nature of the Rainbow Mix collection ensures that the ecosystem remains vibrant, with new opportunities for token holders emerging as the collection expands.

## Further
By implementing a process that binds various NFTs (Non-Fungible Tokens) to a specific token, we can facilitate the tokenization and trading of Real World Assets (RWA) on the blockchain. This advancement opens up innovative opportunities for hedge funds and organizations to manage capital, trade assets, and establish pools of assets. The Rainbow Mix ecosystem is designed to be a stepping stone towards this future, offering a glimpse of the potential for tokenized asset pools.

## Conclusion

Rainbow Mix (RBM) stands at the intersection of innovation and inclusivity, offering a novel pathway for participation in the NFT market. Through RBM, investors can partake in a dynamic collection of NFTs, with the simplicity of ERC20 transactions and the thrill of NFT ownership. As the Rainbow Mix collection grows, so too does the potential for RBM token holders to be part of a unique and diversified digital art and asset portfolio. Join us in building a colorful future with Rainbow Mix, where every token holds the promise of something extraordinary.

## Usage

### Pre Requisites

Before running any command, make sure to install dependencies:

```sh
yarn install
```

### Compile

Compile the smart contracts with Hardhat:

```sh
yarn compile
```

### Test

Run the tests:

```sh
yarn test
```

#### Test gas costs

To get a report of gas costs, set env `REPORT_GAS` to true

To take a snapshot of the contract's gas costs

```sh
yarn test:gas
```


