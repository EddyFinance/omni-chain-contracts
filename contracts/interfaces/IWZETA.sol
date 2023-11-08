interface IWZETA {
    function approve(address guy, uint wad) external returns (bool);
    function transfer(address dst, uint wad) external returns (bool);
    function withdraw(uint wad) external;
    function deposit() external payable;
}