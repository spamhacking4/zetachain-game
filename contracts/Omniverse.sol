// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@zetachain/protocol-contracts/contracts/evm/interfaces/ZetaInterfaces.sol";
import "@zetachain/protocol-contracts/contracts/evm/tools/ZetaInteractor.sol";
import "@openzeppelin/contracts/utils/Strings.sol"; // Import the Strings library

interface OmniverseErrors {
    error InvalidMessageType();
    error InvalidTransferCaller();
    error ErrorApprovingZeta();
}

contract Omniverse is
    ERC721Enumerable,
    ZetaInteractor,
    ZetaReceiver,
    OmniverseErrors
{
    using Counters for Counters.Counter;
    using Strings for uint256; // Use the Strings library for uint256 to string conversion

    mapping(uint256 => string) private _tokenURIs;
    mapping(address => uint256) private _balances;


    bytes32 public constant CROSS_CHAIN_TRANSFER_MESSAGE =
        keccak256("CROSS_CHAIN_TRANSFER");

    IERC20 internal immutable _zetaToken;

    string public baseURI;

    Counters.Counter public tokenIds;

    ZetaTokenConsumer private immutable _zetaConsumer;

    constructor(
        address connectorAddress,
        address zetaTokenAddress,
        address zetaConsumerAddress,
        bool useEven
    ) ZetaInteractor(connectorAddress) ERC721("Omniverse", "CCWAR") {
        _zetaToken = IERC20(zetaTokenAddress);
        _zetaConsumer = ZetaTokenConsumer(zetaConsumerAddress);

        /**
         * @dev A simple way to prevent collisions between cross-chain token ids
         * As you can see below, the mint function should increase the counter by two
         */
        tokenIds.increment();
        if (useEven) tokenIds.increment();
    }

    function setBaseURI(string memory baseURIParam) public onlyOwner {
        baseURI = baseURIParam;
    }

    function mint(address to, string memory tokenURI) public returns (uint256) {
        uint256 newWarriorId = tokenIds.current();

        /**
         * @dev Always increment by two to keep ids even/odd (depending on the chain)
         * Check the constructor for further reference
         */
        tokenIds.increment();
        tokenIds.increment();

        _safeMint(to, newWarriorId);
        _setTokenURI(newWarriorId, tokenURI);

        return newWarriorId;
    }

    /**
     * @dev Useful for cross-chain minting
     */
    function _mintId(address to, uint256 tokenId, string memory tokenURI) internal {
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, tokenURI);
    }

    function _burnWarrior(uint256 burnedWarriorId) internal {
        _burn(burnedWarriorId);
    }

    /**
     * @dev Cross-chain functions
     */

    function crossChainTransfer(
        uint256 crossChainId,
        address to,
        uint256 tokenId
    ) external payable {
        if (!_isValidChainId(crossChainId)) revert InvalidDestinationChainId();
        if (!_isApprovedOrOwner(_msgSender(), tokenId))
            revert InvalidTransferCaller();

        uint256 crossChainGas = 18 * (10 ** 18);
        uint256 zetaValueAndGas = _zetaConsumer.getZetaFromEth{
            value: msg.value
        }(address(this), crossChainGas);
        _zetaToken.approve(address(connector), zetaValueAndGas);

        _burnWarrior(tokenId);

        connector.send(
            ZetaInterfaces.SendInput({
                destinationChainId: crossChainId,
                destinationAddress: interactorsByChainId[crossChainId],
                destinationGasLimit: 500000,
                message: abi.encode(
                    CROSS_CHAIN_TRANSFER_MESSAGE,
                    tokenId,
                    msg.sender,
                    to,
                    _tokenURIs[tokenId]
                ),
                zetaValueAndGas: zetaValueAndGas,
                zetaParams: abi.encode("")
            })
        );
    }

    function onZetaMessage(
        ZetaInterfaces.ZetaMessage calldata zetaMessage
    ) external override isValidMessageCall(zetaMessage) {
        (
            bytes32 messageType,
            uint256 tokenId,
            ,
            address to,
            string memory tokenURI
        ) = abi.decode(
            zetaMessage.message,
            (bytes32, uint256, address, address, string)
        );

        if (messageType != CROSS_CHAIN_TRANSFER_MESSAGE)
            revert InvalidMessageType();

        _mintId(to, tokenId, tokenURI);
    }

    function onZetaRevert(
        ZetaInterfaces.ZetaRevert calldata zetaRevert
    ) external override isValidRevertCall(zetaRevert) {
        (bytes32 messageType, uint256 tokenId, address from, string memory tokenURI) = abi.decode(
            zetaRevert.message,
            (bytes32, uint256, address, string)
        );

        if (messageType != CROSS_CHAIN_TRANSFER_MESSAGE)
            revert InvalidMessageType();

        _mintId(from, tokenId, tokenURI);
    }

    function getTokensByWallet(address wallet) public view returns (string[] memory, string[] memory) {
        uint256 tokenCount = balanceOf(wallet);
        string[] memory tokenIds = new string[](tokenCount);
        string[] memory tokenURIs = new string[](tokenCount);

        for (uint256 i = 0; i < tokenCount; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(wallet, i);
            string memory tokenIdStr = tokenId.toString(); // Convert tokenId to string
            string memory tokenURI = _tokenURIs[tokenId];

            tokenIds[i] = tokenIdStr;
            tokenURIs[i] = tokenURI;
        }

        return (tokenIds, tokenURIs);
    }

    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual {
        _tokenURIs[tokenId] = _tokenURI;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return _tokenURIs[tokenId];
    }
}
