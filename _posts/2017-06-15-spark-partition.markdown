---
layout:     post
title:      "spark partitioner: PageRank"
subtitle:   " \"通过PageRank演示通信开销\""
date:       2017-06-14 21:00:00
author:     "Jc"
header-img: "img/in-post/post-NN/server-2160321_960_720.jpg"
catalog: true
tags:
    - Spark
    - HashPartitioner
    - Scala
    - PageRank
    - join
---

> "A great talker is a great liar."

##  Spark数据分区
&emsp;&emsp;在Spark分布式程序中，通信的代价是很大的，因此控制数据分布一伙的最少的网络传输可以极大地提升整体性能。和单节点的程序需要为记录集合选择合适的数据结构一样，Spark程序可以通过控制RDD的分区方式来减少通信开销。分区并不是对所有应用都有好处的——比如，如果给定RDD只需要被扫描一次，我么完全没有必要对其预先进行分区处理。只有当数据集多次在诸如**连接**这种基于键的操作中使用时，分区才会有帮助。

###  分区神器:partitionBy
&emsp;&emsp;Spark中所有的键值对RDD都可以进行分区。系统会根据一个针对键的函数对元素进行分组。尽管Spark没有给出显式控制每个键具体落在哪一个工作节点上的方法（部分原因是Spark即使在某些节点失败时依然可以工作），但Spark可以确保同一组的键出现在同一个节点上。比如，你可能使用哈希分区将一个RDD分成了100个分区，此时键的哈希值**对100取模**的结果相同的记录会被放在一个节点上。你也可以使用范围分区法，将键在同一个范围区间内的记录都放在同一个节点上。

&emsp;&emsp;举个栗子说明为什么需要分区。现在我们有两个key-value文件，任务要求我们对他们进行一个join操作（需要根据key对数据进行分组)。这两个文件分别是一个user profile(用户画像，大文件)和一个user action(五分钟的用户行为，小文件)，其格式为(userID, userInfo)和(userID, userAction)，userInfo包含该用户订阅历史，userAction为该用户在一个网站上的操作记录。一个示例应用如下所示：

{% highlight scala %}
// 初始化，从hdfs读入userProfile， userLog
// userData中的元素会根据它们被读取时的来源，即HDFS块所在的节点来分布
// Spark此时无法获知某个特定的userID对应的记录位于哪个节点上
val sc = new SparkContext(...)
val userData = sc.textFile("/home/temp/userProfile").persist()

// 周期性调用函数处理过去五分钟的用户行为
def processNewLogs(logFileName: String) {
  val events = sc.textFile("/home/temp/userLog")
  val joined = userData.join(events)  // RDD of (userID, (userInfo, userAction)) pairs

  val offTopicVisits = joined.filter {
    case (userID, (userInfo, userAction)) =>
      userInfo.contains(userAction)
  }.count

  println("number of visits to subscribed:" + offTopicVisits)
}
{% endhighlight %}

这段代码虽然可以运行，但是效率不是最高，我们可以对其进行一些优化。低效率的原因是函数processNewLogs包含join()操作，每次调用连接操作会将用到的键的哈希值都求出来，将该哈希值相同的记录通过网络传到同一台机器上，在这台机器上进行连接操作。每次join操作都会计算userData和event的键的哈希值并进行shuffle,虽然这些数据从来都不会变化。解决这个问题很简单：在读入userProfile时，使用partitionBy()转化操作，将这张表转化为哈希分区。

{% highlight scala %}
val sc = new SparkContext(...)
val userData = sc.textFile("/home/temp/userProfile")
  .partitionBy(new HashPartitioner(100))   // 构造100个分区
  .persist()
{% endhighlight %}

由于在构建userData时调用了partitionBy(),Spark就知道了该RDD根据键的哈希值来分区的，这样Spark就能够利用这一点，寻找到对应的RDD位于哪个分区。具体来说，当调用userData.join(events)时，Spark只会对events进行shuffle操作，把events中特定的userID的记录发送到userData的对应分区所在的那台机器上，程序间通信数据减少，效率大大滴提升了。
在这个问题中有几点注意问题：
* partitionBy()是transform operation
* 应该对partitionBy()的结果持久化
* partitionBy的参数100表示分区数目，这个值至少应该和集群中的总核心数(\-\-total-executor-cores)相等