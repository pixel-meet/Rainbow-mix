// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

library CardManagementLib {
    struct CardType {
        bytes32 firstName;
        bytes32 breed;
        bytes32[3] attacks;
        uint256 life;
        bytes img;
        uint256 generation;
    }

    struct CreateCardTypeParams {
        bytes32[] firstNames;
        bytes32[] breedTypes;
        bytes32[] attacks;
        bytes32[] specialAttacks;
        bytes32[] rareBreeds;
        bytes32[] rareAttacks;
        bytes32[] rareSpecialAttacks;
        bytes[] imgSources;
        bytes[] rareImageSources;
        uint256 maxLife;
        uint256 generation;
    }

    struct CardData {
        mapping(uint256 => CardType) cardTypes;
        uint256 cardTypeLength;
    }

    struct RarityParams {
        uint256 randBase;
        bool isRareBreed;
        bool isRareAttack;
        bool isRareSpecialAttack;
        bool isRareImage;
    }

    struct CardCreationContext {
        CreateCardTypeParams params;
        RarityParams rarity;
        uint256 id;
    }

    function generateRandom(uint256 seed, uint256 mod) internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, blockhash(block.number - 1), seed))) % mod;
    }

    function createCardType(CardData storage data, CreateCardTypeParams memory params) internal returns (uint256) {
        data.cardTypeLength++;
        uint256 id = data.cardTypeLength;
        RarityParams memory rarity = computeRarityParams(id);

        CardCreationContext memory ctx = CardCreationContext({ params: params, rarity: rarity, id: id });

        CardType memory newCardType = constructCardType(ctx);
        data.cardTypes[id] = newCardType;

        return id;
    }

    function constructCardType(CardCreationContext memory ctx) internal view returns (CardType memory) {
        bytes32 breed = selectBreed(ctx.params, ctx.rarity);
        bytes32 firstName = ctx.params.firstNames[generateRandom(ctx.id, ctx.params.firstNames.length)];

        return
            CardType({
                firstName: firstName,
                breed: breed,
                attacks: selectAttacks(ctx.params, ctx.rarity),
                life: generateRandom(ctx.id, ctx.params.maxLife) + 1,
                img: selectImage(ctx.params, ctx.rarity),
                generation: ctx.params.generation
            });
    }

    function computeRarityParams(uint256 id) internal view returns (RarityParams memory) {
        uint256 randBase = generateRandom(id, 100);
        return
            RarityParams({
                randBase: randBase,
                isRareBreed: (randBase % 5) == 0,
                isRareAttack: (randBase % 10) == 0,
                isRareSpecialAttack: (randBase % 15) == 0,
                isRareImage: (randBase % 20) == 0
            });
    }

    function selectAttacks(
        CreateCardTypeParams memory params,
        RarityParams memory rarity
    ) internal view returns (bytes32[3] memory) {
        bytes32[3] memory selectedAttacks;
        selectedAttacks[0] = rarity.isRareAttack
            ? params.rareAttacks[generateRandom(rarity.randBase, params.rareAttacks.length)]
            : params.attacks[generateRandom(rarity.randBase, params.attacks.length)];
        selectedAttacks[1] = params.attacks[generateRandom(rarity.randBase + 1, params.attacks.length)];
        selectedAttacks[2] = rarity.isRareSpecialAttack
            ? params.rareSpecialAttacks[generateRandom(rarity.randBase + 2, params.rareSpecialAttacks.length)]
            : params.specialAttacks[generateRandom(rarity.randBase + 3, params.specialAttacks.length)];
        return selectedAttacks;
    }

    function selectBreed(
        CreateCardTypeParams memory params,
        RarityParams memory rarity
    ) internal view returns (bytes32) {
        return
            rarity.isRareBreed
                ? params.rareBreeds[generateRandom(rarity.randBase, params.rareBreeds.length)]
                : params.breedTypes[generateRandom(rarity.randBase, params.breedTypes.length)];
    }

    function selectImage(
        CreateCardTypeParams memory params,
        RarityParams memory rarity
    ) internal view returns (bytes memory) {
        return
            rarity.isRareImage
                ? params.rareImageSources[generateRandom(rarity.randBase, params.rareImageSources.length)]
                : params.imgSources[generateRandom(rarity.randBase, params.imgSources.length)];
    }
}
