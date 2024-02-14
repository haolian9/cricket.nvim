促织

an opinionated mpv frontend lives in nvim


## features/limits
* utilize libmpv
* stateless across nvim restarting
* search playlists in a defined library root
* playlist-oriented operations
* crude UI


## status
* just works (tm)
* the use of ffi may crash nvim
* feature-complete


## prerequisites
* mpv/libmpv 0.37.0
* nvim 0.9.*
* zig 0.11.*
* haolian9/infra.nvim
* haolian9/puff.nvim


## build
`zig build -Doptimize=ReleaseSafe`

## quick start
* `$ lib=~/.local/state/nvim/cricket` # see cricket.facts.root
* `$ mkdir $lib`
* `$ find /foo/album -name '*.mp3' > $lib/foo` # create a playlist
* `:lua require'cricket'.ctl()` # the main UI
* see more keymaps in `cricket.ui.ctl`
* see more operations to the mpv player in `cricket.player`

---

宣德间，宫中尚促织之戏，岁征民间。此物故非西产；有华阴令欲媚上官，以一头进，试使斗而才，因责常供。令以责之里正。市中游侠儿得佳者笼养之，昂其直，居为奇货。里胥猾黠，假此科敛丁口，每责一头，辄倾数家之产。

邑有成名者，操童子业，久不售。为人迂讷，遂为猾胥报充里正役，百计营谋不能脱。不终岁，薄产累尽。会征促织，成不敢敛户口，而又无所赔偿，忧闷欲死。妻曰：“死何裨益？不如自行搜觅，冀有万一之得。”成然之。早出暮归，提竹筒铜丝笼，于败堵丛草处，探石发穴，靡计不施，迄无济。即捕得三两头，又劣弱不中于款。宰严限追比，旬余，杖至百，两股间脓血流离，并虫亦不能行捉矣。转侧床头，惟思自尽。

时村中来一驼背巫，能以神卜。成妻具资诣问。见红女白婆，填塞门户。入其舍，则密室垂帘，帘外设香几。问者爇香于鼎，再拜。巫从旁望空代祝，唇吻翕辟，不知何词。各各竦立以听。少间，帘内掷一纸出，即道人意中事，无毫发爽。成妻纳钱案上，焚拜如前人。食顷，帘动，片纸抛落。拾视之，非字而画：中绘殿阁，类兰若。后小山下，怪石乱卧，针针丛棘，青麻头伏焉。旁一蟆，若将跳舞。展玩不可晓。然睹促织，隐中胸怀。折藏之，归以示成。

成反复自念，得无教我猎虫所耶？细瞻景状，与村东大佛阁真逼似。乃强起扶杖，执图诣寺后，有古陵蔚起。循陵而走，见蹲石鳞鳞，俨然类画。遂于蒿莱中侧听徐行，似寻针芥。而心目耳力俱穷，绝无踪响。冥搜未已，一癞头蟆猝然跃去。成益愕，急逐趁之，蟆入草间。蹑迹披求，见有虫伏棘根。遽扑之，入石穴中。掭以尖草，不出；以筒水灌之，始出，状极俊健。逐而得之。审视，巨身修尾，青项金翅。大喜，笼归，举家庆贺，虽连城拱璧不啻也。上于盆而养之，蟹白栗黄，备极护爱，留待限期，以塞官责。

成有子九岁，窥父不在，窃发盆。虫跃掷径出，迅不可捉。及扑入手，已股落腹裂，斯须就毙。儿惧，啼告母。母闻之，面色灰死，大惊曰：“业根，死期至矣！而翁归，自与汝复算耳！”儿涕而出。

未几，成归，闻妻言，如被冰雪。怒索儿，儿渺然不知所往。既得其尸于井，因而化怒为悲，抢呼欲绝。夫妻向隅，茅舍无烟，相对默然，不复聊赖。日将暮，取儿藁葬。近抚之，气息惙然。喜置榻上，半夜复苏。夫妻心稍慰，但儿神气痴木，奄奄思睡。成蟋蟀笼虚，顾之则气断声吞，亦不敢复究儿。自昏达曙，目不交睫。东曦既驾，僵卧长愁。忽闻门外虫鸣，惊起觇视，虫宛然尚在。喜而捕之，一鸣辄跃去，行且速。覆之以掌，虚若无物；手裁举，则又超忽而跃。急趋之，折过墙隅，迷其所在。徘徊四顾，见虫伏壁上。审谛之，短小，黑赤色，顿非前物。成以其小，劣之。惟彷徨瞻顾，寻所逐者。壁上小虫忽跃落襟袖间，视之，形若土狗，梅花翅，方首，长胫，意似良。喜而收之。将献公堂，惴惴恐不当意，思试之斗以觇之。

村中少年好事者驯养一虫，自名“蟹壳青”，日与子弟角，无不胜。欲居之以为利，而高其直，亦无售者。径造庐访成，视成所蓄，掩口胡卢而笑。因出己虫，纳比笼中。成视之，庞然修伟，自增惭怍，不敢与较。少年固强之。顾念蓄劣物终无所用，不如拼博一笑，因合纳斗盆。小虫伏不动，蠢若木鸡。少年又大笑。试以猪鬣毛撩拨虫须，仍不动。少年又笑。屡撩之，虫暴怒，直奔，遂相腾击，振奋作声。俄见小虫跃起，张尾伸须，直龁敌领。少年大骇，急解令休止。虫翘然矜鸣，似报主知。成大喜。方共瞻玩，一鸡瞥来，径进以啄。成骇立愕呼，幸啄不中，虫跃去尺有咫。鸡健进，逐逼之，虫已在爪下矣。成仓猝莫知所救，顿足失色。旋见鸡伸颈摆扑，临视，则虫集冠上，力叮不释。成益惊喜，掇置笼中。

翼日进宰，宰见其小，怒诃成。成述其异，宰不信。试与他虫斗，虫尽靡。又试之鸡，果如成言。乃赏成，献诸抚军。抚军大悦，以金笼进上，细疏其能。既入宫中，举天下所贡蝴蝶、螳螂、油利挞、青丝额一切异状遍试之，无出其右者。每闻琴瑟之声，则应节而舞。益奇之。上大嘉悦，诏赐抚臣名马衣缎。抚军不忘所自，无何，宰以卓异闻，宰悦，免成役。又嘱学使俾入邑庠。后岁余，成子精神复旧，自言身化促织，轻捷善斗，今始苏耳。抚军亦厚赉成。不数岁，田百顷，楼阁万椽，牛羊蹄躈各千计；一出门，裘马过世家焉。

异史氏曰：“天子偶用一物，未必不过此已忘；而奉行者即为定例。加以官贪吏虐，民日贴妇卖儿，更无休止。故天子一跬步，皆关民命，不可忽也。独是成氏子以蠹贫，以促织富，裘马扬扬。当其为里正、受扑责时，岂意其至此哉？天将以酬长厚者，遂使抚臣、令尹，并受促织恩荫。闻之：一人飞升，仙及鸡犬。信夫！”
