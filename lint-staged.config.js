module.exports = {
  "src/**/*.sol": ["prettier --write --plugin=prettier-plugin-solidity", "solhint --max-warnings 0"],
  "{test,script}/**/*.sol": "prettier --write --plugin=prettier-plugin-solidity",
};
