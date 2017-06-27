---
layout:     post
title:      "Scala: 合并两个Map"
subtitle:   " \"scala中快速简洁地合并两个map\""
date:       2017-06-26 21:00:00
author:     "Jc"
header-img: "img/in-post/post-scala/scala-merge-two-map.jpeg"
catalog: true
tags:
    - Scala
    - Map
---

> "You are not in charge of the universe; you are in charge of yourself."

##  应用场景
&emsp;&emsp;最近在一个项目中需要把Scala的两个Map合并，合并的时候会遇到相同的键和不同的键，对与相同的键，合并后的值是两个Map的值的和，对于只存在于一个Map中的键保留其值不变，对于下面两个map的合并

{% highlight scala%}
scala> val m1 = Map(1->10, 2->4)
m1: scala.collection.immutable.Map[Int,Int] = Map(1 -> 10, 2 -> 4)

scala> val m2 = Map(2->5, 4->8)
m2: scala.collection.immutable.Map[Int,Int] = Map(2 -> 5, 4 -> 8)
{% endhighlight %}

其结果是应该是这样的
{% highlight scala%}
scala> 
m3: scala.collection.immutable.Map[Int,Int] = Map(1 -> 10, 2 -> 9, 4 -> 8)
{% endhighlight %}

如果我们简单地采用scala中的magic sugar ++ 方法，其结果成为这样
{% highlight scala%}
scala> m1 ++ m2
res0: scala.collection.immutable.Map[Int,Int] = Map(1 -> 10, 2 -> 5, 4 -> 8)
{% endhighlight %}
这里结果显然不符合预期，我们希望key=2的value是4+5=9，而这里等于5，说明在两个map merge时第二个map的key-value:(2,5)覆盖了第一个map的值(2,4).

### Solution1: brute force
最简单的方法是for loop，这种方法不但代码冗长而且效率低下，我们想尝试更有效的方法

{% highlight scala%}
scala> val m3 = scala.collection.mutable.Map[Int, Int]()
res1: scala.collection.immutable.Map[Int,Int] = Map(1 -> 10, 2 -> 5, 4 -> 8)

scala> for((k,v)<-m2){if (m3.contains(k)) m3(k) += m2(k) else m3(k) = m2(k)}

scala> m3
res2: scala.collection.mutable.Map[Int,Int] = Map(2 -> 5, 4 -> 8)

scala> for((k,v)<-m1){if (m3.contains(k)) m3(k) += m1(k) else m3(k) = m1(k)}

scala> m3
res3: scala.collection.mutable.Map[Int,Int] = Map(2 -> 9, 4 -> 8, 1 -> 10)

scala> m3.toMap
res4: scala.collection.immutable.Map[Int,Int] = Map(2 -> 9, 4 -> 8, 1 -> 10)
{% endhighlight %}

### Solution2: groupBy

{% highlight scala%}
scala> val list = m1.toList ++ m2.toList
list: List[(Int, Int)] = List((1,10), (2,4), (2,5), (4,8))

scala> val merged = list.groupBy ( _._1) .map { case (k,v) => k -> v.map(_._2).sum }
merged: scala.collection.immutable.Map[Int,Int] = Map(2 -> 9, 4 -> 8, 1 -> 10)
{% endhighlight %}

此方法先把Map转化成list，然后进行一个groupBy操作，把相同的key聚合到一起，之后进行一个求和。该方法有点是可以处理更多个Map的merge，但缺点也是显而易见的，Map转化为List又转回Map造成了一定开销，并且groupBy代价比较大。还有没有别的方法呢？有的。

### Solution3: foldLeft
{% highlight scala%}
scala> val merged = (m1 /: m2) { case (map, (k,v)) =>
         map + ( k -> (v + map.getOrElse(k, 0)) )
        }
merged: scala.collection.immutable.Map[Int,Int] = Map(1 -> 10, 2 -> 9, 4 -> 8)
{% endhighlight %}

这部分代码比较抽象，其中(m1 /: m2) 等价于 m2.foldLeft(m1)，可以形象地理解为向左折叠。而foldLeft参数需要接收两个，另外一个参数列表使用case 匹配到一个结果map 和 当前m1中的一个（k,v) pair，这个pair就是foldLeft过程中遍历的每一个值。通过这些操作最终获得我们需要的结果，这个方法已经够简洁高效了，还有更简单的方法吗？有的。

### Solution4: scalaz
scalaz封装了一个更加优美的二元函数操作符|+|，直接操作两个Map就能得到结果。首先启动scala时附带加入scalaz的包。关于scalaz的说明和下载如下
* [scalaz in Github][1]
* [scalaz Document][2]
* [download jar of scalaz][3]
从这里已下载到scalaz的jar包之后就可以在启动scala的时候引入这个包
{% highlight shell_session%}
$ scala -cp scalaz-core_2.11-7.1.1.jar 
{% endhighlight %}
在shell中导入scalaz.Scalaz._就可以使用它的隐式“\|+\|”操作符来merge我们的两个Map了，非常简洁。
{% highlight scala%}
scala> import scalaz.Scalaz._
import scalaz.Scalaz._

scala> m1 |+| m2
res5: scala.collection.immutable.Map[Int,Int] = Map(2 -> 9, 4 -> 8, 1 -> 10)
{% endhighlight %}

### 参考链接
* [stackoverflow: Best way to merge two maps and sum the values of same key?][4]
* [scala - 从合并两个Map说开去 - foldLeft 和 foldRight 还有模式匹配][5]
* [Use scalaz in console repl without creating a project][6]

[1]: https://github.com/scalaz/scalaz
[2]: http://scalaz.github.io/scalaz/
[3]: http://book2s.com/java/jar/s/scalaz-core-2-11/download-scalaz-core_2.11-7.1.1.html
[4]: https://stackoverflow.com/questions/7076128/best-way-to-merge-two-maps-and-sum-the-values-of-same-key
[5]: http://www.cnblogs.com/tugeler/p/5134862.html
[6]: https://stackoverflow.com/questions/16526282/use-scalaz-in-console-repl-without-creating-a-project