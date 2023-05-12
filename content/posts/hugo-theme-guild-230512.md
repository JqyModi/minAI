---
title: "Hugo Theme Guild 230512"
date: 2023-05-12T11:49:04+08:00
draft: false
cover:
    image: "img/icon_search.png" # image path/url
    alt: "alt text" # alt text
    caption: "this is a caption" # display caption under cover
    relative: false # when using page bundles set this to true
    hidden: false # only hide on current single page
---

### [主题仓库](themes.gohugo.io)

### 安装步骤
- 拉取模板代码
    ```
    git submodule add --depth=1 https://github.com/adityatelange/hugo-PaperMod.git themes/PaperMod
    git submodule update --init --recursive # needed when you reclone your repo (submodules may not get cloned automatically)
    ```
- 配置主题
    > config.yml文件中添加`theme: "PaperMod"`

- [配置案例](https://github.com/adityatelange/hugo-PaperMod/wiki/Installation#sample-configyml)
    - 主项目配置：`config.yml`
        ```
        baseURL: 'https://jqymodi.github.io/minAI/'
        languageCode: 'en-us'
        title: 'MinAI'
        # 设置主题
        theme: 'PaperMod'
        # 设置每页显示数量
        paginate: 5

        # enableRobotsTXT: true
        # buildDrafts: false
        # buildFuture: false
        # buildExpired: false

        # googleAnalytics: UA-123-45

        # tag等间距调整
        # minify:
        #   disableXML: true
        #   minifyOutput: true

        params:
        env: production # to enable google analytics, opengraph, twitter-cards and schema.
        title: ExampleSite
        description: "ExampleSite description"
        keywords: [Blog, Portfolio, PaperMod]
        author: Me
        # author: ["Me", "You"] # multiple authors
        images: ["<link or path of image for opengraph, twitter-cards>"]
        DateFormat: "January 2, 2006"
        defaultTheme: auto # dark, light
        disableThemeToggle: false

        ShowReadingTime: true
        ShowShareButtons: true
        ShowPostNavLinks: true
        ShowBreadCrumbs: true
        ShowCodeCopyButtons: false
        ShowWordCount: true
        ShowRssButtonInSectionTermList: true
        UseHugoToc: true
        disableSpecial1stPost: false
        disableScrollToTop: false
        comments: false
        hidemeta: false
        hideSummary: false
        showtoc: false
        tocopen: false

        assets:
            # disableHLJS: true # to disable highlight.js
            # disableFingerprinting: true
            favicon: "<link / abs url>"
            favicon16x16: "<link / abs url>"
            favicon32x32: "<link / abs url>"
            apple_touch_icon: "<link / abs url>"
            safari_pinned_tab: "<link / abs url>"

        label:
            text: "Home"
            icon: /apple-touch-icon.png
            iconHeight: 35

        # profile-mode
        profileMode:
            enabled: false # needs to be explicitly set
            title: ExampleSite
            subtitle: "This is subtitle"
            imageUrl: "<img location>"
            imageWidth: 120
            imageHeight: 120
            imageTitle: my image
            buttons:
            - name: Posts
                url: posts
            - name: Tags
                url: tags

        # home-info mode
        homeInfoParams:
            Title: "Hi there \U0001F44B"
            Content: Welcome to my blog

        socialIcons:
            - name: twitter
            url: "https://twitter.com/"
            - name: stackoverflow
            url: "https://stackoverflow.com"
            - name: github
            url: "https://github.com/"

        analytics:
            google:
            SiteVerificationTag: "XYZabc"
            bing:
            SiteVerificationTag: "XYZabc"
            yandex:
            SiteVerificationTag: "XYZabc"

        cover:
            hidden: true # hide everywhere but not in structured data
            hiddenInList: true # hide on list pages and home
            hiddenInSingle: true # hide on single page

        editPost:
            URL: "https://github.com/<path_to_repo>/content"
            Text: "Suggest Changes" # edit text
            appendFilePath: true # to append file path to Edit link

        # for search
        # https://fusejs.io/api/options.html
        fuseOpts:
            isCaseSensitive: false
            shouldSort: true
            location: 0
            distance: 1000
            threshold: 0.4
            minMatchCharLength: 0
            keys: ["title", "permalink", "summary", "content"]
        menu:
        main:
            - identifier: categories
            name: categories
            url: /categories/
            weight: 20
            - identifier: tags
            name: tags
            url: /tags/
            weight: 30
            - identifier: example
            name: example.org
            url: https://example.org
            weight: 40
            - identifier: search
            name: search
            url: /search
            weight: 10
            # pre: '<svg xmlns="http://www.w3.org/2000/svg" width="28" height="28" viewBox="0 0 24 24" fill="none"
            #       stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            #       <circle cx="11" cy="11" r="8"></circle>
            #       <line x1="21" y1="21" x2="16.65" y2="16.65"></line>
            #   </svg>'
            pre: <img src="img/icon_search.png" style="width:12px; height:12px; display:block;" />
        # Read: https://github.com/adityatelange/hugo-PaperMod/wiki/FAQs#using-hugos-syntax-highlighter-chroma
        pygmentsUseClasses: true
        markup:
        highlight:
            noClasses: false
            # anchorLineNos: true
            # codeFences: true
            # guessSyntax: true
            # lineNos: true
            # style: monokai

        # 搜索模块固定配置
        outputs:
            home:
                - HTML
                - RSS
                - JSON # is necessary
        ```
    - 子页面：`page.md`
        ```
        title: "Domain 230510"
        description: "Desc Text."
        date: 2023-05-10T13:53:39+08:00
        draft: false
        # weight: 1
        # aliases: ["/first"]
        tags: ["first"]
        author: "Me"
        # author: ["Me", "You"] # multiple authors
        showToc: true # 目录显示
        TocOpen: false # 目前打开关闭
        hidemeta: false # 隐藏用户action信息：浏览时间等小字
        comments: false
        # 当一个网页存在多个URL可以访问时，通过该属性来指定主URL，避免被搜索引擎误判为重复内容影响SEO
        canonicalURL: "https://canonical.url/to/page"
        # disableHLJS: true # 是否高亮JS代码
        disableShare: false
        hideSummary: false #隐藏摘要：首页摘要
        searchHidden: false
        ShowReadingTime: true
        ShowBreadCrumbs: true
        ShowPostNavLinks: true
        ShowWordCount: true
        ShowRssButtonInSectionTermList: true
        UseHugoToc: true
        cover:
            image: "<image path/url>" # image path/url
            alt: "<alt text>" # alt text
            caption: "<text>" # display caption under cover
            relative: false # when using page bundles set this to true
            hidden: true # only hide on current single page
        editPost:
            URL: "https://github.com/<path_to_repo>/content"
            Text: "Suggest Changes" # edit text
            appendFilePath: true # to append file path to Edit link
        ```
    



