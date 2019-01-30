# Introduction

I love programming in Ruby. For years I've been wishing AWS would release an officially supported Lambda runtime for Ruby. Thankfully it finally happened.

I excitedly read through every example. Unfortunately, they were all basically variants on the Hello World example. I couldn't find anything that implemented any complex tasks, so I started trying it myself and quickly ran into a problem: gems with C extensions.

What follows is a description of the problem, and my first attempts to work around it. Specifically, I'm looking at the mysql2 gem since that's what I needed initially, but this approach should work for most gems. **It should be noted that I do not consider this to be a necessarily good solution.** It's something that is more or less working, but it's currently held together by a lot of duct tape and chewing gum. My hope is that it will spark something in someone else's mind that will lead to a better solution. I've included some of my thoughts at the end.

I should also mention that my goal is to do as much as possible using the SAM framework.

# The Problem

Many ruby gems include C extensions that need to be compiled for the host machine that will run them. In addition, they need runtime libraries available to link against. However, for obvious reasons, the lambda container is stripped down to the bare essential packages necessary to do its job. It does not contain much in the way of native libraries such as database client libs or compression libraries.

There are two issues we need to address. The first is how to build the ruby gems to be compatible with the lambda runtime and the second is how to provide it with the runtime libraries (e.g., .so files) that it can link against when it gets called.

## Providing runtime dependencies

I tackled this problem first because it was the most obviously needed. Initially, my thought was that if I'm running Ruby 2.5 locally I can have the gem compile itself on my local workstation, and, assuming I could inject the shared libraries, it would just work. _Spoiler alert: It didn't._

The first most obvious possibility is to just copy the .so files into the lambda package. The `LD_LIBRARY_PATH` variable in the lambda runtime includes some directories in the lambda package, so it would be able to find them, however I don't like this idea because it makes the package far bigger than I'd like. Not only would I have to check them into my source repo (eww), but the package would swell to the point where I can no longer view the code in the lambda console.

The next obvious choice is lambda layers. They're perfectly suited for just this use case. A layer is just a zip file that unpacks into /opt, so I should be able to just copy the .so files from my workstation into a zip file and go to town. However, this is potentially very fragile. A better solution would be to get them from an actual lambda runtime. I wrote a very simple [Dockerfile](Dockerfile) to spit out the lambda layer.

That seemed to have solved that problem, so I continued on.

## Compiling the gem

My first naive attempt was to just call sam build and let it compile the gem against my local ruby install and drop it in the container. As you might expect, that failed spectacularly. The biggest problem was that the local ruby shared library is dynamically linked, but the one in the lambda container is statically linked.

Obviously, this sort of issue is intended to be solved with the `--use-container` flag. However, in this case, that fails because the mysql2 compilation can't find the development headers.

The build happens as an unprivileged user so having the headers installed on the fly isn't an option.

The solution I came up with for now is to pre-compile the gem in an environment that looks exactly like the standard lambda build container but with the needed libraries added in.

The upside is that the gem is compatible and ready to run and you don't necessarily need to use the build container flag which speeds things up. The downside is that it has to be done ahead of time and hosted somewhere. We have a nexus repository, so I created a repo there to put it in. An S3 bucket would work just as well.

# Future potential

My initial thought is that we could add some additional metadata to the SAM template that lists the additional yum packages that need to be installed for both build time and runtime. Something like this:

```yaml
MyFunction:
  Type: AWS::Serverless::Function
  Metadata:
    Packages:
	  Build:
	    - mysql-devel
	  Runtime:
	    - mysql-libs 
```

When the package command is run, it would inject the packages into the build container.  Additionally, it would pull the files from the runtime packages, build them into a layer, register the layer, and put the ARN in the list of layers for the function. Ideally, something would be done to test whether the layer is already there with the proper versions of the libraries to avoid duplication on every build.

Another possibility would be something like a buildspec file like codebuild uses. SAM could use that to build layers, transform the template, and inject build dependencies into the build environment.

The real goal is to get to the point where 'sam build' can build all the various pieces required to support the function even if those pieces include OS level packages.