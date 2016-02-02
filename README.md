接口包含
- Init(UpdateListFile, RootPath, [, FailNotify, ENV])
- Update()

Init负责初始化，RootPath是你的lua文件目录，该目录及子目录下的所有的lua文件都被纪录。UpdateListFile是一个lua路径，要求这个lua文件返回一个table，这个table包含想要热更新的文件的文件名。

Update每运行一次就对UpdateListFile里面的文件进行热更新，只更新函数，不更新数据。

~限Windows平台使用, 详细配置[lua热更新](https://asqbtcupid.github.io/hotupdte-implement/)





![例子动图](https://raw.githubusercontent.com/asqbtcupid/asqbtcupid.github.com/master/images/hotupdate-example.gif)
