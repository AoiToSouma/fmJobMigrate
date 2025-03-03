const Xdc3 = require("xdc3");

const rpc = 'https://erpc.apothem.network';
const address = process.argv[2];

const xdc3 = new Xdc3(new Xdc3.providers.HttpProvider(rpc));
const checksumAddress = xdc3.utils.toChecksumAddress(address);

console.log(checksumAddress);
