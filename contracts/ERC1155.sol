// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "./IERC1155.sol";
import "./IERC1155Metadata.sol";
import "./Receiver/IERC1155R.sol";
import "../library/SafeMath.sol";
import "../library/Address.sol";


contract ERC1155 is IERC1155, IERC1155MetadataURI {
    using SafeMath for uint256;
    using Address for address;

    // id => creators
    mapping (uint256 => address) public creators;
    // Mapping from token ID to account balances
    mapping(uint256 => mapping(address => uint256)) private _balances;

    // Mapping from account to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;
     
    // Used as the URI for all token types by relying on ID substition, e.g. https://token-cdn-domain/{id}.json

    mapping(uint256 => string) private _uri;
    /**
        @dev Get the specified address' balance for token with specified ID.
        Attempting to query the zero account for a balance will result in a revert.
        @param account The address of the token holder
        @param id ID of the token
        @return The account's balance of the token type requested
     */
    
    function balanceOf(address account, uint256 id)
        public
        view
        override
        returns (uint256)
    {
        require(
            account != address(0),
            "ERC1155: balance query for the zero address"
        );
        return _balances[id][account];
    }

    /**
        @dev Get the balance of multiple account/token pairs.
        If any of the query accounts is the zero account, this query will revert.
        @param accounts The addresses of the token holders
        @param ids IDs of the tokens
        @return Balances for each account and token id pair
     */
    function balanceOfBatch(address[] memory accounts, uint256[] memory ids)
        public
        view
        override
        returns (uint256[] memory)
    {
        require(
            accounts.length == ids.length,
            "ERC1155: accounts and IDs must have same lengths"
        );

        uint256[] memory batchBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ++i) {
            require(
                accounts[i] != address(0),
                "ERC1155: some address in batch balance query is zero"
            );
            batchBalances[i] = _balances[ids[i]][accounts[i]];
        }

        return batchBalances;
    }

    /**
     * @dev Sets or unsets the approval of a given operator.
     *
     * An operator is allowed to transfer all tokens of the sender on their behalf.
     *
     * Because an account already has operator privileges for itself, this function will revert
     * if the account attempts to set the approval status for itself.
     *
     * @param operator address to set the approval
     * @param approved representing the status of the approval to be set
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        require(
            msg.sender != operator,
            "ERC1155: cannot set approval status for self"
        );
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    /**
        @notice Queries the approval status of an operator for a given account.
        @param account   The account of the Tokens //owner
        @param operator  Address of authorized operator
        @return           True if the operator is approved, false if not
    */
    function isApprovedForAll(address account, address operator)
        public
        view
        override
        returns (bool)
    {
        return _operatorApprovals[account][operator];
    }

    /**
        @dev Transfers `value` amount of an `id` from the `from` address to the `to` address specified.
        Caller must be approved to manage the tokens being transferred out of the `from` account.
        If `to` is a smart contract, will call `onERC1155Received` on `to` and act appropriately.
        @param from Source address
        @param to Target address
        @param id ID of the token type
        @param value Transfer amount
        @param data Data forwarded to `onERC1155Received` if `to` is a contract receiver
    */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 value,
        bytes memory data
    ) public override {
        require(to != address(0), "ERC1155: target address must be non-zero");
        require(
            from == msg.sender || isApprovedForAll(from, msg.sender) == true,
            "ERC1155: need operator approval for 3rd party transfers"
        );

        _balances[id][from] = _balances[id][from].sub(
            value,
            "ERC1155: insufficient balance for transfer"
        );
        _balances[id][to] = _balances[id][to].add(value);

        emit TransferSingle(msg.sender, from, to, id, value);

        _doSafeTransferAcceptanceCheck(msg.sender, from, to, id, value, data);
    }

    /**
        @dev Transfers `values` amount(s) of `ids` from the `from` address to the
        `to` address specified. Caller must be approved to manage the tokens being
        transferred out of the `from` account. If `to` is a smart contract, will
        call `onERC1155BatchReceived` on `to` and act appropriately.
        @param from Source address
        @param to Target address
        @param ids IDs of each token type
        @param values Transfer amounts per token type
        @param data Data forwarded to `onERC1155Received` if `to` is a contract receiver
    */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) public override {
        require(
            ids.length == values.length,
            "ERC1155: IDs and values must have same lengths"
        );
        require(to != address(0), "ERC1155: target address must be non-zero");
        require(
            from == msg.sender || isApprovedForAll(from, msg.sender) == true,
            "ERC1155: need operator approval for 3rd party transfers"
        );

        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 value = values[i];

            _balances[id][from] = _balances[id][from].sub(
                value,
                "ERC1155: insufficient balance of some token type for transfer"
            );
            _balances[id][to] = _balances[id][to].add(value);
        }

        emit TransferBatch(msg.sender, from, to, ids, values);

        _doSafeBatchTransferAcceptanceCheck(
            msg.sender,
            from,
            to,
            ids,
            values,
            data
        );
    }
    function mint(address to, uint256 id, uint256 value, bytes memory data) public returns (bool) {
        _mint(to, id, value, data);
        return true;
    }
    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) public returns (bool) {
        _mintBatch(
        to,
        ids,
        values,
        data
    );
        return true;
    }
    /**
     * @dev Internal function to mint an amount of a token with the given ID
     * @param to The address that will own the minted token
     * @param id ID of the token to be minted
     * @param value Amount of the token to be minted
     * @param data Data forwarded to `onERC1155Received` if `to` is a contract receiver
     */
    function _mint(address to, uint256 id, uint256 value, bytes memory data)
        internal
        virtual
    {
        require(to != address(0), "ERC1155: mint to the zero address");

        _balances[id][to] = _balances[id][to].add(value);
        emit TransferSingle(msg.sender, address(0), to, id, value);

        _doSafeTransferAcceptanceCheck(
            msg.sender,
            address(0),
            to,
            id,
            value,
            data
        );
    }

    /**
     * @dev Internal function to batch mint amounts of tokens with the given IDs
     * @param to The address that will own the minted token
     * @param ids IDs of the tokens to be minted
     * @param values Amounts of the tokens to be minted
     * @param data Data forwarded to `onERC1155Received` if `to` is a contract receiver
     */
    function _mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) internal virtual {
        require(to != address(0), "ERC1155: batch mint to the zero address");
        require(
            ids.length == values.length,
            "ERC1155: minted IDs and values must have same lengths"
        );

        for (uint256 i = 0; i < ids.length; i++) {
            _balances[ids[i]][to] = values[i].add(_balances[ids[i]][to]);
        }

        emit TransferBatch(msg.sender, address(0), to, ids, values);

        _doSafeBatchTransferAcceptanceCheck(
            msg.sender,
            address(0),
            to,
            ids,
            values,
            data
        );
    }
    modifier creatorOnly(uint256 _id) {
        require(creators[_id] == msg.sender,
        "is not the creator");
        _;
    }
    function setURI(string calldata _Uri, uint256 _id) external creatorOnly(_id) {
        _uri[_id] = _Uri;
    }
   
    function uri(uint256 id) external view override returns (string memory) {
        return _uri[id];
    }
//oz
    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 value,
        bytes memory data
    ) private {
        if (to.isContract()) {
            require(
                IERC1155Receiver(to).onERC1155Received(
                    operator,
                    from,
                    id,
                    value,
                    data
                ) == IERC1155Receiver(to).onERC1155Received.selector,
                "ERC1155: got unknown value from onERC1155Received"
            );
        }
    }
//oz

    function _doSafeBatchTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) private {
        if (to.isContract()) {
            require(
                IERC1155Receiver(to).onERC1155BatchReceived(
                    operator,
                    from,
                    ids,
                    values,
                    data
                ) == IERC1155Receiver(to).onERC1155BatchReceived.selector,
                "ERC1155: got unknown value from onERC1155BatchReceived"
            );
        }
    }
}
