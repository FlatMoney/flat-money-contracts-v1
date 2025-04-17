module.exports = {
  "src/**/!(*flattened).sol": "solhint --max-warnings 0",
  "{src,test,script}/**/*.sol": "prettier --write --plugin=prettier-plugin-solidity",
};
