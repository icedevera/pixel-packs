//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "base64-sol/base64.sol";

contract PixelPackFactory is ERC721URIStorage, VRFConsumerBase, Ownable {
    struct AttributeOdds {
        uint256 darkAuraOdds;
        uint256 lightAuraOdds;
        uint256 darkStrokeOdds;
        uint256 lightStrokeOdds;
        uint256 corruptOdds;
        uint256 nobleOdds;
    }

    AttributeOdds public attributeOdds;

    struct PixelPackMap {
        bool darkAura;
        bool lightAura;
        bool darkStroke;
        bool lightStroke;
        bool corrupt;
        bool noble;
        uint256 corruptSchema;
        uint8[] schema;
        string[] colors;
    }

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
        uint256 corruptSchema;
        uint8[] schema;
        string[] colors;
    }

    PixelPack[] public pixelPacks;

    event NewPixelPack(uint256 indexed tokenId, string tokenURI);

    mapping(uint256 => address) public pixelPackToOwner;
    mapping(address => uint256) ownerPixelPackCount;

    // Random number generation via ChainlinkVRF:
    bytes32 internal keyHash;
    uint256 internal fee;

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
        uint256[] memory _attributeOdds
    )
        ERC721("PixelPacks", "PXP")
        VRFConsumerBase(_VRFCoordinator, _LinkToken)
        Ownable()
    {
        keyHash = _keyHash;
        fee = _fee;

        attributeOdds = AttributeOdds(
            _attributeOdds[0],
            _attributeOdds[1],
            _attributeOdds[2],
            _attributeOdds[3],
            _attributeOdds[4],
            _attributeOdds[5]
        );
    }

    function generatePixelPack() public returns (bytes32 _requestId) {
        _requestId = requestRandomness(keyHash, fee);
        requestIdToSender[_requestId] = msg.sender;

        string memory name = string(
            abi.encodePacked("PXP #", uintToStr((pixelPacks.length)))
        );

        pixelPacks.push(
            PixelPack({
                name: name,
                darkAura: false,
                lightAura: false,
                darkStroke: false,
                lightStroke: false,
                corrupt: false,
                noble: false,
                randomNumber: 0,
                corruptSchema: 0,
                schema: new uint8[](0),
                colors: new string[](0)
            })
        );

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
            (pixelPacks.length) > _tokenId,
            "Token ID has not yet been minted."
        );
        require(
            pixelPacks[_tokenId].randomNumber > 0,
            "Random number has yet to be fulfilled."
        );

        uint256 randomNumber = pixelPacks[_tokenId].randomNumber;

        PixelPackMap memory pixelPackMap;

        pixelPackMap = generateMap(randomNumber, attributeOdds);

        pixelPacks[_tokenId].colors = pixelPackMap.colors;
        pixelPacks[_tokenId].schema = pixelPackMap.schema;
        pixelPacks[_tokenId].darkAura = pixelPackMap.darkAura;
        pixelPacks[_tokenId].lightAura = pixelPackMap.lightAura;
        pixelPacks[_tokenId].darkStroke = pixelPackMap.darkStroke;
        pixelPacks[_tokenId].lightStroke = pixelPackMap.lightStroke;
        pixelPacks[_tokenId].corrupt = pixelPackMap.corrupt;
        pixelPacks[_tokenId].corruptSchema = pixelPackMap.corruptSchema;

        string memory svg = generateSVG(pixelPackMap);
        string memory imageURI = svgToImageURI(svg);
        string memory tokenURI = formatTokenURI(
            imageURI,
            pixelPacks[_tokenId].name,
            _tokenId
        );

        _setTokenURI(_tokenId, tokenURI);
        emit NewPixelPack(_tokenId, tokenURI);
    }

    function generateMap(
        uint256 _randomNumber,
        AttributeOdds memory _attributeOdds
    ) internal pure returns (PixelPackMap memory pixelPackMap) {
        uint256[] memory randomNumbers = expand(
            _randomNumber,
            74 // 3 is the number of colors + 64 is the number of cells + 6 is the number of attributes + 1 for the corrupt schema
        );

        pixelPackMap.colors = new string[](3);

        for (uint8 i = 0; i < 3; i++) {
            pixelPackMap.colors[i] = string(
                abi.encodePacked("#", uintToHexStr(randomNumbers[i] % 16777216))
            );
        }

        pixelPackMap.schema = new uint8[](64);

        for (uint8 i = 0; i < 64; i++) {
            pixelPackMap.schema[i] = uint8((randomNumbers[i + 3]) % 3);
        }

        uint256 attributeIndex = 67; // compensate for the already used expanded random numbers

        pixelPackMap.darkAura =
            (randomNumbers[attributeIndex] % _attributeOdds.darkAuraOdds) == 0;
        pixelPackMap.lightAura =
            (randomNumbers[attributeIndex + 1] %
                _attributeOdds.lightAuraOdds) ==
            0;
        pixelPackMap.darkStroke =
            (randomNumbers[attributeIndex + 2] %
                _attributeOdds.darkStrokeOdds) ==
            0;
        pixelPackMap.lightStroke =
            (randomNumbers[attributeIndex + 3] %
                _attributeOdds.lightStrokeOdds) ==
            0;
        pixelPackMap.corrupt =
            (randomNumbers[attributeIndex + 4] % _attributeOdds.corruptOdds) ==
            0;
        pixelPackMap.noble =
            (randomNumbers[attributeIndex + 5] % _attributeOdds.nobleOdds) == 0;

        if (pixelPackMap.corrupt) {
            pixelPackMap.corruptSchema =
                randomNumbers[attributeIndex + 6] %
                192; // 192 = 64 number of cells * 3 corruption positions
        }

        return pixelPackMap;
    }

    function generateSVG(PixelPackMap memory _pixelPackMap)
        internal
        pure
        returns (string memory finalSVG)
    {
        finalSVG = string(
            abi.encodePacked(
                "<svg xmlns='http://www.w3.org/2000/svg' overflow='visible' height='",
                uintToStr(680),
                "' width='",
                uintToStr(680),
                "' fill='transparent' "
            )
        );

        // conditions for border
        if (_pixelPackMap.darkAura && _pixelPackMap.lightAura) {
            // fuse dark and light to create glass
            finalSVG = string(
                abi.encodePacked(finalSVG, "filter='url(#glass)' ")
            );
        } else if (_pixelPackMap.darkAura || _pixelPackMap.lightAura) {
            // create aura border
            finalSVG = string(
                abi.encodePacked(finalSVG, "filter='url(#aura)' ")
            );
        }

        // conditions for outline
        if (_pixelPackMap.darkStroke && _pixelPackMap.lightStroke) {
            // fuse dark and light to create overflow
            finalSVG = string(
                abi.encodePacked(
                    finalSVG,
                    "stroke='url(#overflow)' stroke-width='3px' "
                )
            );
        } else if (_pixelPackMap.darkStroke) {
            // create dark outline
            finalSVG = string(
                abi.encodePacked(
                    finalSVG,
                    "stroke='#000000' stroke-width='3px' "
                )
            );
        } else if (_pixelPackMap.lightStroke) {
            // create light outline
            finalSVG = string(
                abi.encodePacked(
                    finalSVG,
                    "stroke='#FFFFFF' stroke-width='3px' "
                )
            );
        }

        finalSVG = string(abi.encodePacked(finalSVG, ">"));

        // define effects
        if (
            _pixelPackMap.darkAura ||
            _pixelPackMap.lightAura ||
            (_pixelPackMap.darkStroke && _pixelPackMap.lightStroke)
        ) {
            finalSVG = string(abi.encodePacked(finalSVG, "<defs>"));

            // define border
            if (_pixelPackMap.darkAura && _pixelPackMap.lightAura) {
                // define glass
                finalSVG = string(
                    abi.encodePacked(
                        finalSVG,
                        "<filter id='glass'><feGaussianBlur in='SourceGraphic' stdDeviation='10' result='blur'/><feColorMatrix in='blur' mode='matrix' values='1 0 0 0 0 0 1 0 0 0 0 0 1 0 0 0 0 0 17 -2.15'/><feComposite in='SourceGraphic' operator='over'/></filter>"
                    )
                );
            } else if (_pixelPackMap.darkAura || _pixelPackMap.lightAura) {
                // define dark aura
                finalSVG = string(
                    abi.encodePacked(
                        finalSVG,
                        "<filter id='aura' height='300%' width='300%' x='-75%' y='-75%'><feMorphology operator='dilate' radius='4' in='SourceAlpha' result='thicken'/><feGaussianBlur in='thicken' stdDeviation='15' result='blurred'/><feFlood flood-color="
                    )
                );

                if (_pixelPackMap.darkAura) {
                    finalSVG = string(abi.encodePacked(finalSVG, "'#000000' "));
                }

                if (_pixelPackMap.lightAura) {
                    finalSVG = string(abi.encodePacked(finalSVG, "'#FFDF4F' "));
                }

                finalSVG = string(
                    abi.encodePacked(
                        finalSVG,
                        "result='glowColor'/><feComposite in='glowColor 'in2='blurred' operator='in' result='softGlow_colored'/><feMerge><feMergeNode in='softGlow_colored'/><feMergeNode in='SourceGraphic'/></feMerge></filter>"
                    )
                );
            }

            if (_pixelPackMap.darkStroke && _pixelPackMap.lightStroke) {
                finalSVG = string(
                    abi.encodePacked(
                        finalSVG,
                        "<linearGradient id='overflow' x1='50%' y1='0%' x2='75%' y2='100%'><stop offset='0%' stop-color='#F79533'><animate attributeName='stop-color' values='#F79533;#F37055;#EF4E7B;#A166AB;#5073B8;#1098AD;#07B39B;#6DBA82;#F79533' dur='4s' repeatCount='indefinite'></animate></stop><stop offset='100%' stop-color='#F79533'><animate attributeName='stop-color' values='#F37055;#EF4E7B;#A166AB;#5073B8;#1098AD;#07B39B;#6DBA82;#F79533;#F37055' dur='4s' repeatCount='indefinite'></animate></stop></linearGradient>"
                    )
                );
            }

            finalSVG = string(abi.encodePacked(finalSVG, "</defs>"));
        }

        string memory color1 = _pixelPackMap.colors[0];
        string memory color2 = _pixelPackMap.colors[1];
        string memory color3 = _pixelPackMap.colors[2];

        for (uint256 i = 0; i < 64; i++) {
            string memory color = _pixelPackMap.colors[_pixelPackMap.schema[i]];

            if (_pixelPackMap.corrupt || _pixelPackMap.noble) {
                finalSVG = string(
                    abi.encodePacked(
                        finalSVG,
                        "<rect",
                        " width='",
                        uintToStr(85), // svgSize / numberof Cells = width
                        "' height='",
                        uintToStr(85), // svgSize / numberof Cells = height
                        "' x='",
                        uintToStr(((85) * (i % 8))),
                        "' y='",
                        uintToStr(((85) * (i / 8))),
                        "' fill='",
                        color,
                        "'>"
                    )
                );

                if (
                    (_pixelPackMap.corrupt && _pixelPackMap.noble) ||
                    _pixelPackMap.corrupt
                ) {
                    string memory corruption1 = "transparent";
                    string memory corruption2 = "transparent";

                    if (readWithBitmap(_pixelPackMap.corruptSchema, i)) {
                        corruption1 = "#000000";
                    }

                    if (readWithBitmap(_pixelPackMap.corruptSchema, i + 64)) {
                        corruption2 = "#000000";
                    }

                    if (_pixelPackMap.corrupt && _pixelPackMap.noble) {
                        finalSVG = string(
                            abi.encodePacked(
                                finalSVG,
                                "<animate attributeName='fill' dur='5s' values='",
                                color,
                                ";",
                                color1,
                                ";",
                                corruption1,
                                ";",
                                color2,
                                ";",
                                corruption2,
                                ";",
                                color3,
                                ";",
                                color,
                                ";",
                                color,
                                ";' ",
                                "keyTimes='0; 0.05; .10; .15; .20; .25; .30; 1' repeatCount='indefinite'/>"
                            )
                        );
                    } else if (_pixelPackMap.corrupt) {
                        string memory corruption3 = "transparent";

                        if (
                            readWithBitmap(_pixelPackMap.corruptSchema, i + 128)
                        ) {
                            corruption3 = "#000000";
                        }

                        finalSVG = string(
                            abi.encodePacked(
                                finalSVG,
                                "<animate attributeName='fill' dur='5s' values='",
                                color,
                                ";",
                                corruption1,
                                ";",
                                color,
                                ";",
                                corruption2,
                                ";",
                                corruption3,
                                ";' ",
                                "keyTimes='0; 0.9; 0.92; .96; .98' calcMode='discrete' repeatCount='indefinite'/>"
                            )
                        );
                    }
                } else if (_pixelPackMap.noble) {
                    finalSVG = string(
                        abi.encodePacked(
                            finalSVG,
                            "<animate attributeName='fill' dur='10s' values='",
                            color,
                            "; ",
                            color1,
                            "; ",
                            color2,
                            "; ",
                            color3,
                            "; ",
                            color,
                            "; ",
                            color,
                            ";' ",
                            "keyTimes='0;0.1;0.15;0.2;0.25;1' repeatCount='indefinite'/>"
                        )
                    );
                }

                finalSVG = string(abi.encodePacked(finalSVG, "</rect>"));
            } else {
                finalSVG = string(
                    abi.encodePacked(
                        finalSVG,
                        "<rect",
                        " width='",
                        uintToStr(85),
                        "' height='",
                        uintToStr(85),
                        "' x='",
                        uintToStr(((85) * (i % 8))),
                        "' y='",
                        uintToStr(((85) * (i / 8))),
                        "' fill='",
                        color,
                        "'/>"
                    )
                );
            }
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

    // Expand Chainlink VRF random number to multiple random numbers of count n
    function expand(uint256 randomValue, uint256 n)
        public
        pure
        returns (uint256[] memory expandedValues)
    {
        expandedValues = new uint256[](n);
        for (uint256 i = 0; i < n; i++) {
            expandedValues[i] = uint256(keccak256(abi.encode(randomValue, i)));
        }
        return expandedValues;
    }

    // https://soliditydeveloper.com/bitmaps
    // reads a bitmap and returns a boolean depending if the indexed bit is a 1 or a 0
    function readWithBitmap(uint256 bitMap, uint256 indexFromRight)
        internal
        pure
        returns (bool)
    {
        uint256 bitAtIndex = bitMap & (1 << indexFromRight);
        return bitAtIndex > 0;
    }

    // From: https://stackoverflow.com/questions/47129173
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
