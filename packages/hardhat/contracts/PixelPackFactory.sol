//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "base64-sol/base64.sol";

contract PixelPackFactory is ERC721URIStorage, VRFConsumerBase, Ownable {
    //Pixel Pack NFT Params
    uint256 gridDimension;
    uint256 numberOfColors;

    // special attribute odds
    uint256 darkAuraOdds;
    uint256 lightAuraOdds;
    uint256 darkStrokeOdds;
    uint256 lightStrokeOdds;
    uint256 corruptOdds;
    uint256 nobleOdds;

    // PixelPack Data
    struct PixelPack {
        string name;
        bool darkAura;
        bool lightAura;
        bool darkStroke;
        bool lightStroke;
        bool corrupt;
        bool noble;
        uint256 randomNumber;
        uint256[] schema;
        string[] colors;
    }

    PixelPack[] public pixelPacks;

    event NewPixelPack(uint256 indexed tokenId, string tokenURI);

    mapping(uint256 => address) public pixelPackToOwner;
    mapping(address => uint256) ownerPixelPackCount;

    // SVG Params
    uint256 svgSize;

    // Random number generation via ChainlinkVRF:
    bytes32 internal keyHash;
    uint256 internal fee;
    uint256 public randomResult;

    event RandomNumberRequested(
        bytes32 indexed requestId,
        uint256 indexed tokenId
    );

    event RandomNumberFulfilled(uint256 indexed tokenId, uint256 randomNumber);

    mapping(bytes32 => address) public requestIdToSender;
    mapping(bytes32 => uint256) public requestIdToTokenId;

    constructor(
        address _VRFCoordinator,
        address _LinkToken,
        bytes32 _keyHash,
        uint256 _fee,
        uint256 _svgSize,
        uint256 _gridDimension,
        uint256 _numberOfColors,
        uint256 _darkAuraOdds,
        uint256 _lightAuraOdds,
        uint256 _darkStrokeOdds,
        uint256 _lightStrokeOdds,
        uint256 _corruptOdds,
        uint256 _nobleOdds
    )
        ERC721("PixelPacks", "PXP")
        VRFConsumerBase(_VRFCoordinator, _LinkToken)
        Ownable()
    {
        keyHash = _keyHash;
        fee = _fee;
        gridDimension = _gridDimension;
        svgSize = _svgSize;
        numberOfColors = _numberOfColors;

        darkAuraOdds = _darkAuraOdds;
        lightAuraOdds = _lightAuraOdds;
        darkStrokeOdds = _darkStrokeOdds;
        lightStrokeOdds = _lightStrokeOdds;
        corruptOdds = _corruptOdds;
        nobleOdds = _nobleOdds;
    }

    function generatePixelPack() public returns (bytes32 _requestId) {
        _requestId = requestRandomness(keyHash, fee);
        requestIdToSender[_requestId] = msg.sender;

        string memory name = string(
            abi.encodePacked("PXP #", uintToStr(pixelPacks.length - 1))
        );

        pixelPacks.push(PixelPack(name, 0, new string[](0), new uint256[](0)));
        uint256 tokenId = pixelPacks.length - 1;
        requestIdToTokenId[_requestId] = tokenId;
        pixelPackToOwner[tokenId] = msg.sender;
        ownerPixelPackCount[msg.sender] = ownerPixelPackCount[msg.sender] + 1;
        emit RandomNumberRequested(_requestId, tokenId);
    }

    function fulfillRandomness(bytes32 _requestId, uint256 _randomNumber)
        internal
        override
    {
        address nftOwner = requestIdToSender[_requestId];
        uint256 tokenId = requestIdToTokenId[_requestId];
        _safeMint(nftOwner, tokenId);
        pixelPacks[tokenId].randomNumber = _randomNumber;
        emit RandomNumberFulfilled(tokenId, _randomNumber);
    }

    function finishMint(uint256 _tokenId) public {
        require(
            bytes(tokenURI(_tokenId)).length <= 0,
            "tokenURI is alreay set."
        );
        require(
            (pixelPacks.length - 1) > _tokenId,
            "Token ID has not yet been minted."
        );
        require(
            pixelPacks[_tokenId].randomNumber > 0,
            "Random number has yet to be fulfilled."
        );

        uint256 randomNumber = pixelPacks[_tokenId].randomNumber;
        string[] memory colors;
        uint256[] memory schema;
        bool darkAura;
        bool lightAura;
        bool darkStroke;
        bool lightStroke;
        bool corrupt;
        bool noble;

        (
            colors,
            schema,
            darkAura,
            lightAura,
            darkStroke,
            lightStroke,
            corrupt,
            noble
        ) = generateMap(randomNumber);

        pixelPacks[_tokenId].colors = colors;
        pixelPacks[_tokenId].schema = schema;

        string memory svg = generateSVG(colors, schema);
        string memory imageURI = svgToImageURI(svg);
        string memory tokenURI = formatTokenURI(
            imageURI,
            pixelPacks[_tokenId].name,
            _tokenId
        );

        _setTokenURI(_tokenId, tokenURI);
        emit NewPixelPack(_tokenId, tokenURI);
    }

    // Expand Chainlink VRF random number to multiple random numbers of count n
    function expand(uint256 randomValue, uint256 n)
        internal
        pure
        returns (uint256[] memory expandedValues)
    {
        expandedValues = new uint256[](n);
        for (uint256 i = 0; i < n; i++) {
            expandedValues[i] = uint256(keccak256(abi.encode(randomValue, i)));
        }
        return expandedValues;
    }

    function generateMap(uint256 _randomNumber)
        internal
        view
        returns (
            string[] memory,
            uint256[] memory,
            bool darkAura,
            bool lightAura,
            bool darkStroke,
            bool lightStroke,
            bool corrupt,
            bool noble
        )
    {
        uint256 numberOfCells = gridDimension**2;

        uint256[] memory randomNumbers = expand(
            _randomNumber,
            numberOfColors + numberOfCells + 6 // 6 is the number of attributes
        );

        string[] memory colors = new string[](numberOfColors);

        for (uint256 i = 0; i < numberOfColors; i++) {
            uint256 colorDecimal = randomNumbers[i] % 16777216;
            string memory colorHex = uintToHexStr(colorDecimal);
            string memory color = string(abi.encodePacked("#", colorHex));
            colors[i] = color;
        }

        uint256[] memory schema = new uint256[](numberOfCells);

        for (uint256 i = 0; i < numberOfCells; i++) {
            uint256 currentRandomNumberIndex = i + numberOfColors;
            uint256 randomColor = randomNumbers[currentRandomNumberIndex] %
                numberOfColors;
            schema[i] = randomColor;
        }

        bool memory darkAura;
        bool memory lightAura;
        bool memory darkStroke;
        bool memory lightStroke;
        bool memory corrupt;
        bool memory noble;

        uint256 memory attributeIndex = numberOfColors + numberOfCells;

        darkAura = (randomNumbers[attributeIndex] % darkAuraOdds) == 0;
        lightAura = (randomNumbers[attributeIndex + 1] % lightAuraOdds) == 0;
        darkStroke = (randomNumbers[attributeIndex + 2] % darkStrokeOdds) == 0;
        lightStroke =
            (randomNumbers[attributeIndex + 3] % lightStrokeOdds) == 0;
        corrupt = (randomNumbers[attributeIndex + 4] % corruptOdds) == 0;
        noble = (randomNumbers[attributeIndex + 5]) == 0;

        return (colors, schema, darkAura, lightAura, outline, corrupt, noble);
    }

    function generateSVG(string[] memory _colors, uint256[] memory _schema)
        internal
        view
        returns (string memory finalSVG)
    {
        finalSVG = string(
            abi.encodePacked(
                "<svg xmlns='http://www.w3.org/2000/svg' height='",
                uintToStr(svgSize),
                "' width='",
                uintToStr(svgSize),
                "'>"
            )
        );

        uint256 cellSize = svgSize / gridDimension;
        uint256 numberOfCells = gridDimension**2;

        for (uint256 i = 0; i < numberOfCells; i++) {
            uint256 row = i / gridDimension;
            uint256 col = i % gridDimension;
            uint256 x = cellSize * col;
            uint256 y = cellSize * row;

            string memory color = _colors[_schema[i]];

            finalSVG = string(
                abi.encodePacked(
                    finalSVG,
                    "<rect",
                    " width='",
                    uintToStr(cellSize),
                    "' height='",
                    uintToStr(cellSize),
                    "' x='",
                    uintToStr(x),
                    "' y='",
                    uintToStr(y),
                    "' fill='",
                    color,
                    "' />"
                )
            );
        }

        finalSVG = string(abi.encodePacked(finalSVG, "</svg>"));
    }

    // You could also just upload the raw SVG and have solildity convert it!
    function svgToImageURI(string memory _svg)
        internal
        pure
        returns (string memory)
    {
        string memory baseURL = "data:image/svg+xml;base64,";
        string memory svgBase64Encoded = Base64.encode(
            bytes(string(abi.encodePacked(_svg)))
        );
        return string(abi.encodePacked(baseURL, svgBase64Encoded));
    }

    function formatTokenURI(
        string memory _imageURI,
        string memory _name,
        uint256 _tokenId
    ) internal pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                '{"name":"',
                                _name,
                                '", "description":"Pixel Pack #',
                                uintToStr(_tokenId),
                                '", "attributes":"", "image":"',
                                _imageURI,
                                '"}'
                            )
                        )
                    )
                )
            );
    }

    // From: https://stackoverflow.com/a/65707309/11969592
    function uintToStr(uint256 _i)
        internal
        pure
        returns (string memory _uintAsString)
    {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }

    // From: https://stackoverflow.com/questions/69301408/solidity-convert-hex-number-to-hex-string
    function uintToHexStr(uint256 i) internal pure returns (string memory) {
        if (i == 0) return "0";
        uint256 j = i;
        uint256 length;
        while (j != 0) {
            length++;
            j = j >> 4;
        }
        uint256 mask = 15;
        bytes memory bstr = new bytes(length);
        uint256 k = length;
        while (i != 0) {
            uint256 curr = (i & mask);
            bstr[--k] = curr > 9
                ? bytes1(uint8(55 + curr))
                : bytes1(uint8(48 + curr)); // 55 = 65 - 10
            i = i >> 4;
        }
        return string(bstr);
    }
}
