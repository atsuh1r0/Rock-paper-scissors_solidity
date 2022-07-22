pragma solidity ^0.8.12;
contract RockPaperScissors {
    address payable public owner;
    
    // コンストラクタ
    constructor() {
        owner = payable(msg.sender);
    }

    // 変数定義
    uint OneEther = 1 ether; // 通貨
    uint fee = OneEther; // 掛け金
    mapping (address => bool) participants; 
    address payable[] participants_vector = new address payable[](2); 
    uint participant_number = 0;
    mapping (address => uint256) choice_value;
    mapping (address => uint256) hash_value;
    mapping (address => bool) isGHV;
    uint T_S = 0;
    uint T_V;
    uint T_F = 0; // 一人目の参加者が来た時間
    uint T_W; // 一人目が来てからの待ち時間
    bool isStartGame = false;
    uint state = 0;
    
    // オーナーによる初期設定
    function preparationOwner(uint vot, uint waitTime) payable public {
        require(msg.sender == owner, "You are not owner");
        require(!isStartGame,"isStartGame is true");
        T_V = vot;
        T_W = waitTime;
        isStartGame = true;
    }

    // どの段階かを把握する、確認用関数
    function returnState() public view returns(bytes32) {
        if(isStartGame) {
            if(participant_number < 2) return "Recruiting participants";
            else {
                if(T_S == 0) return "Before startGame";
                else if(T_S <= block.timestamp && block.timestamp < T_S+T_V && state == 0) return "inputHashValue";
                else if((T_S+T_V <= block.timestamp || state == 1) && block.timestamp <= T_S+T_V*2) return "inputValue";
                else if(T_S+T_V*2 <= block.timestamp || state == 2) return "Reward";
                else return "error";
            }
        } else {
            return "Not start game.";
        }
    }

    // ゲームの開始判定
    function participantReception() payable public {
        require(isStartGame,"isStartGame is false");
        require(msg.sender != owner,"You are not owner");
        require(participant_number < 2,"participant_number is more than 2");
        require(!participants[msg.sender],"You are participants");
        require(msg.value >= fee,"You did not pay deposit enough value"); //デポジット支払
        
        address payable participant = payable(msg.sender);
        participants[participant] = true;
        participants_vector[participant_number] = participant;
        participant_number++;
        isGHV[participant] = false;

        if (participant_number == 1) {
          // 一人目
          T_F = block.timestamp;
        } else if (participant_number == 2) {
          // 二人目
          // 一人目が入室後一定時間以内に二人目が入室したか
          if (T_F+T_W >= block.timestamp) {
            startGame();
            require(T_S != 0, "not update T_S");
          }
        }
    }

    // ゲーム開始時の処理
    function startGame() private {
        require(T_S == 0,"T_S is not 0");
        for(uint i=0;i<2;i++) {
            choice_value[participants_vector[i]] = 3;
        }
        T_S = block.timestamp;
    }

    // じゃんけんで出したものをハッシュ化させてBC上にのせる
    function generateHashValue(uint256 hashValue) public {
        require(participants[msg.sender],"You are not participants");
        require(T_S <= block.timestamp && block.timestamp < T_S+T_V && state == 0,"Now is not inputHashValue time");
        hash_value[msg.sender] = hashValue;
        isGHV[msg.sender] = true;
        if (isGHV[participants_vector[0]] && isGHV[participants_vector[1]]) {
          state = 1;
        }
    }

    // 確認送信用のハッシュ
    function inputValue(uint256 value) public {
        require(participants[msg.sender],"You are not participants");
        require((T_S+T_V <= block.timestamp || state == 1) && block.timestamp <= T_S+T_V*2,"Now is not inputValue time");
        uint256 hashValue = hash(value);
        require(hashValue == hash_value[msg.sender],"The hash value of your input does not match one in advance");
        choice_value[msg.sender] = value%3;
        if (choice_value[participants_vector[0]] != 3 && choice_value[participants_vector[1]] != 3) {
          state = 2;
        }
    }

    // ゲーム終了時の処理
    function finishGame() public {
        require(participants[msg.sender] || msg.sender == owner,"You are not participants and owner");
        require(T_S != 0,"T_S is 0");
        require(T_S+T_V*2 <= block.timestamp || state == 2,"You can not finish Game now");

        // 0:Rock 1:Paper 2:Scissors 3:initial
        if ((choice_value[participants_vector[0]] < 3) && (choice_value[participants_vector[1]] < 3)) {
          // 二人とも手を出した場合
          if ((choice_value[participants_vector[0]] == 0 && choice_value[participants_vector[1]] == 2) 
          || (choice_value[participants_vector[0]] == 1 && choice_value[participants_vector[1]] == 0)
          || (choice_value[participants_vector[0]] == 2 && choice_value[participants_vector[1]] == 1)
          ) {
            // 一人目が勝利
            participants_vector[0].transfer(fee*2);
          } else if ((choice_value[participants_vector[0]] == 0 && choice_value[participants_vector[1]] == 1)
          || (choice_value[participants_vector[0]] == 1 && choice_value[participants_vector[1]] == 2)
          || (choice_value[participants_vector[0]] == 2 && choice_value[participants_vector[1]] == 0)
          ) {
            // 二人目が勝利
            participants_vector[1].transfer(fee*2);
          } else {
            // あいこ
            participants_vector[0].transfer(fee);
            participants_vector[1].transfer(fee);
          }
        } else if ((choice_value[participants_vector[0]] < 3) && (choice_value[participants_vector[1]] == 3)) {
          // 一人目が手を出したが、二人目は手を出さなかった場合
          participants_vector[0].transfer(fee*2);
        } else if ((choice_value[participants_vector[0]] == 3) && (choice_value[participants_vector[1]] < 3)) {
          // 二人目が手を出したが、一人目は手を出さなかった場合
          participants_vector[1].transfer(fee*2);
        }
          // 二人とも手を出さなかった場合は送金しない
        
        // リセット
        resetParameter();
        require(T_S == 0 && participant_number == 0 && !isStartGame,"resetPara failed 1");
        for(uint i=0;i<2;i++) {
            require(!participants[participants_vector[i]],"could not false participants");
            require(choice_value[participants_vector[i]] == 3,"could not be 2 choice_value");
        }
    }
    
    // ハッシュ
    function hash(uint256 inp) public pure returns (uint256){
        bytes memory tmp = toBytes(inp);
        bytes32 tmp2 = sha256(tmp);
        return uint256(tmp2);
    }

    // バイト型に変更
    function toBytes(uint256 x) private pure returns (bytes memory b) {
        b = new bytes(32);
        assembly { mstore(add(b, 32), x) }
    }
    
    // データリセット
    function resetParameter() public {
        participant_number = 0;
        isStartGame = false;
        T_S = 0;
        state = 0;
        for(uint i=0;i<2;i++) {
            isGHV[participants_vector[i]] = false;
            participants[participants_vector[i]] = false;
            choice_value[participants_vector[i]] = 3;
        }
    }
}
