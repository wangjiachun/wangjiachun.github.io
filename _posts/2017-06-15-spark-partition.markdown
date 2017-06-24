---
layout:     post
title:      "Spark Partitioner: PageRank"
subtitle:   " \"通过PageRank演示Spark通信开销\""
date:       2017-06-14 21:00:00
author:     "Jc"
header-img: "img/in-post/post-spark/spark-partition.jpg"
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
* partitionBy的参数100表示分区数目，这个值至少应该和集群中的总核心数(\-\-total-executor-cores)相等
* partitionBy对RDD进行分区，这个分区方式需要被**持久化**才能被用于后面的RDD转化操作

## 获取RDD的分区方式

在Scala中，RDD的partitioner属性可以用来获取RDD的分区方式。它会返回一个scala.Option对象，这是Scala中用来存放可能存在的对象的容器类。如果存在值的话，这个值会是一个spark.Partitioner对象。这本质上是一个告诉我们RDD中各个键属于哪个分区的函数(但是函数细节对我们是透明的)。

{% highlight scala %}
scala> val pairs = sc.parallelize(list((1, 1), (2, 2), (3, 3)))
pairs: spark.RDD[(Int, Int)] = ParallelCollectionRDD[0] at parallelize at <console>:12

scala> pairs.partitioner
res0: Option[spark.Partitioner] = None

scala> val partitioned = pairs.partitionBy(new spark.HashPartitioner(2))
paritioned: spark.RDD[(Int, Int)] = ShuffledRDD[1] at partitionBy at <console>:14

scala> partitioned.partitioner
res1: Option[spark.Partitioner] = Some(spark.HashPartitioner@5137788d)
{% endhighlight %}

在这段spark shell代码中，firstly，创建了一个没有分区方式信息的pairRDD，其partitioner方法返回None的Option对象。之后通过hashPartition的哈希方法给它一个哈希分区方式，使得Spark可以了解到这个RDD是如何存储到不同的节点上的。在实际应用中，通常还要再分区之后增加持久化操作，即persist()。

## 通过分区节省开销：PageRank
PageRank算法可以参考[谷歌链接][1]，这里只是简单介绍一下算法的数据集要求以及实施步骤：
算法会维护两个数据集：一个由（PageID, linkList)的元素组成，包含每个页面的相邻页面的列表；另一个由(pageID, rank)元素组成，包含每个页面的当前排序值。算法步骤如下：

* 将每个页面的排序值初始化为1.0
* 在每次迭代中，对页面p，向其每个相邻页面发送一个值为 rank(p)/numNeighbors(p) 的贡献
* 将每个页面的排序值设为0.15 + 0.85 * contributionReceived

使用Spark实现PageRank：
{% highlight scala %}
// reading page link file
val links = sc.objectFile[(String, Seq[String])]("links")
	.partitionBy(new HashPartitioner(100))
	.persist
// assign weight to 1.0 for each page
var ranks = links.mapValues(v => 1.0)
// 10 iteration
for (i <- 1 to 10) {
	val contribution = links.join(ranks)
		.flatMap{
		case (l,(lst, w)) =>
			lst.map(lk => (lk, w / lst.size.toDouble))
	}
	ranks = contribution.reduceByKey(_ + _).mapValues(v => 0.15 + 0.85 * v)
}
// write as text file
ranks.saveAsTextFile(output_path)
{% endhighlight %}

以上的PageRank算法通过不断更新ranks的值来达到收敛的目的，此处ranks被声明为可变变量。代码通过各种tricks来减小通信开销：
* links每次迭代都会与ranks进行join操作。由于links是一个静态数据集，在这个数据集的基础上进行join操作可以按照links的分区来进行，不需要做shuffle。通常links数据比ranks大很多，因为这个RDD存储的是页面链接的url，而ranks只是存储了一个Double型的页面得分，这个优化操作比不进行分区的实现和mapreduce实现节省了许多通信代价。
* persist方法把links保留在内存中，否则每次join操作用到links的时候都要重新计算一遍。
* 生成ranks的时候使用mapValues可以保留父RDD的分区方式，便于后续join，而且对第一次生成ranks也能有很大帮助。
* 循环体中的reduceByKey可以保留哈希分区的信息，之后接mapValues可以不修改分区信息，提高下一次join的效率。
* 为了减少数据在不同executor之间传输，尽量使用mapValues和flatMapValues，因为他们不改变键值。

引自：Spark快速大数据分析(Holden Karau)_4.5-数据分区


[1]: https://en.wikipedia.org/wiki/PageRank
