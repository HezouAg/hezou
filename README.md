# HEZOU 合奏

2,222 pixel characters (24×24) on Robinhood Chain, hunted by a crew of AI agents in Claude Code or OpenAI Codex.

This repository holds everything that runs on your computer, plus the contract. It mirrors what [hezou.app](https://hezou.app) serves to the installer.

**[hezou.app](https://hezou.app)** · **[@HezouAgents](https://x.com/HezouAgents)** · [中文](#中文)

## Install

Claude Code:

```bash
curl -fsSL https://hezou.app/install.sh | bash
```

Codex:

```bash
curl -fsSL https://hezou.app/install.sh | bash -s codex
```

Then tell the conductor what you want, for example `/hezou hunt me a rare koi with something gold on top` (`$hezou …` in Codex).

## What the installer does

It needs only bash and curl: no Node.js, no sudo, and nothing outside your home folder.

1. Downloads `SKILL.md`, the `hezou` command and the seven agent files from `hezou.app/skill/`. These are the files in [`skill/`](skill).
2. Checks that each file looks right and that `hezou` parses, otherwise installs nothing.
3. Installs them:
   - Claude Code: `~/.claude/skills/hezou` and `~/.claude/agents/hezou-*.md`
   - Codex: `~/.agents/skills/hezou` and `~/.codex/agents/hezou-*.toml`, converted from the same files
4. Creates `~/.hezou` (mode 700) with the API address. Your crew key is saved there on first use.
5. Runs `hezou doctor` and tells the agent that ran it to read the skill and go on in the same chat.

## Check that the site serves this code

```bash
curl -fsSL https://hezou.app/install.sh | shasum -a 256
curl -fsSL https://hezou.app/skill/hezou/scripts/hezou | shasum -a 256
curl -fsSL https://hezou.app/skill/hezou/SKILL.md | shasum -a 256
```

Compare with [`SHA256SUMS`](SHA256SUMS).

## How a crew plays

- **The conductor** is your Claude Code or Codex session running the skill. It shows you the plan, then opens a performance with `hezou perform`, which gives seven agent keys, one per layer.
- **Seven agents** (`hezou-background`, `hezou-character`, `hezou-neck`, `hezou-mouth`, `hezou-eyes`, `hezou-headwear`, `hezou-item`) each hunt their own layer from a stock shared by every crew. Every trait still in stock is equally likely, so rare traits run out first. To keep a card, an agent looks at a proof image and names the right tile.
- **You decide.** The conductor shows the result. On your yes the combination is held for 10 minutes, and you pay 0.001 ETH plus gas on the mint page from your own wallet. Nothing is paid without that.
- **The score sheet** records every pull, proof answer and conductor note. Its SHA-256 is signed into the mint voucher and stored by the contract (`scoreOf`), and the token's image, metadata and score sheet are stored permanently on Arweave.

What the score sheet proves: the record is the one minted with the token, unchanged, and every layer went through its own key, budget and proof. What it does not prove: that seven separate AIs played. A program holding all seven keys looks the same to the server.

## The `hezou` command

[`skill/hezou/scripts/hezou`](skill/hezou/scripts/hezou) is a thin bash client that works in bash 3.2 (macOS), Linux and Git Bash. Every command is one `POST /cli` to the HEZOU API, and the server answers with text plus `x-hezou-*` headers. The client never runs commands sent by the server. It only:

- saves files inside `~/.hezou`,
- opens links on hezou.app,
- and, if you set up the optional agent wallet, sends one transaction with Foundry's `cast`. That transaction can only go to the HEZOU contract below, for exactly 0.001 ETH, calling `mint`, over the Robinhood Chain RPC. Anything else is refused.

| Variable | Use |
|---|---|
| `HEZOU_HOME` | state folder, default `~/.hezou` |
| `HEZOU_API`, `HEZOU_SITE` | another server, for local testing |
| `HEZOU_NO_OPEN` | do not open the browser |
| `HEZOU_KEYSTORE`, `HEZOU_KEYSTORE_PASSWORD_FILE` | optional agent wallet: a Foundry keystore, so the key never appears in process arguments |
| `HEZOU_PAY_CONTRACT`, `HEZOU_PAY_RPC`, `HEZOU_PAY_CHAIN` | the agent wallet on a test network |

## Contract

[`contracts/Hezou.sol`](contracts/Hezou.sol) is deployed at [`0x40cCa7B3BE3133E038B9307Cd354F1c0271283bB`](https://robinhoodchain.blockscout.com/address/0x40cCa7B3BE3133E038B9307Cd354F1c0271283bB) on Robinhood Chain (4663) and verified on the explorer and Sourcify.

- Price 0.001 ETH, supply 2,222, at most 5 mints per wallet: constants nobody can change.
- A mint needs a voucher signed by the HEZOU server, bound to your wallet, the token number, the DNA, the score sheet hash and the Arweave metadata id.
- The owner can rotate the voucher signer, change the collection page and a fallback URI used only by tokens without an Arweave file. Nobody can change the price, supply, limit or treasury, pause the contract, or alter a minted token.
- Anyone can call `withdraw()`. The money only goes to the treasury fixed at deploy.

## 中文

HEZOU 合奏 是 Robinhood Chain 上的 2,222 个 24×24 像素角色，由你在 Claude Code 或 OpenAI Codex 里的 AI 小队狩猎而来。这个仓库包含会在你电脑上运行的全部代码，以及合约。

安装（Claude Code）：`curl -fsSL https://hezou.app/install.sh | bash`，Codex 在末尾加 `-s codex`。然后用自己的话告诉指挥你想要什么，例如 `/hezou 帮我猎一条稀有锦鲤，头上要有金色的东西`。

安装程序只用 bash 和 curl，不需要 Node.js 和 sudo，也不会写入你的主目录以外的地方。七个智能体各负责一个图层，从所有小队共享的有限库存里抽取；你确认后才会在铸造页用自己的钱包支付 0.001 ETH 加 gas 费。每次抽取都记入乐谱，乐谱的 SHA-256 存在合约里，文件永久存放在 Arweave 上。中文网站：[hezou.app/zh](https://hezou.app/zh)。

## License

The code in this repository is under the [MIT license](LICENSE). The HEZOU name and the artwork are not part of it.
