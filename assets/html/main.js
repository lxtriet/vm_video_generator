    let anim
    let openTypeFont = []

    let currentFontFamily = []
    let currentFontFilename = []
    let currentFontBase64 = []
    let currentJson = {}

    let loadedFontFamily = []
    let loadedFontFilename = []
    let loadedFontBase64 = []
    let loadedJson = ''

    let previewFrameNumber = 0
    let previewData = {}
    let gridData = {}
    let textData = []
    let boundingBoxTexts = []
    let prevTime = 0
    let svgX = 0
    let svgY = 0
    let gElement
    let gWidth = 0
    let gHeight = 0
    let textComps
    let styleList = []

    const sleep = ms => new Promise(resolve => setTimeout(resolve, ms))

    function base64ToArrayBuffer(base64) {
        var binary_string = atob(base64)
        var len = binary_string.length
        var bytes = new Uint8Array(len)
        for (var i = 0; i < len; i++) {
            bytes[i] = binary_string.charCodeAt(i)
        }
        return bytes.buffer
    }

    function loadJSON(file) {
        loadedFontFamily = []
        const reader = new FileReader()
        reader.readAsText(file, 'utf8')
        reader.onload = e => {
            loadedJson = JSON.parse(e.target.result)
            if (loadedJson && loadedJson.fonts && Array.isArray(loadedJson.fonts.list)) {
                for (let i = 0; i < loadedJson.fonts.list.length; i++) {
                    const { fFamily } = loadedJson.fonts.list[i]
                    loadedFontFamily.push(fFamily)
                }
                // alert('font-family : ' + loadedFontFamily.join(', '))
            }
        }
    }

    function loadFont(files) {
        loadedFontFilename = []
        for (let i = 0; i < files.length; i++) {
            const reader = new FileReader()
            const file = files[i]
            loadedFontFilename.push(file.name)
            reader.readAsDataURL(file, 'utf8')
            reader.onload = e => {
                loadedFontBase64.push(e.target.result.split('base64,')[1])
            }
        }
    }

    window.onload = function () {
        const jsonEl = document.getElementById("input-json")
        jsonEl.addEventListener('change', e => {
            loadJSON(e.target.files[0])
        })

        const fontEl = document.getElementById("input-font")
        fontEl.addEventListener('change', e => {
            loadFont(e.target.files)
        })
    }

    async function setData({ fontFamily, base64, json, texts }) {
        let sleepCount = 1;
        while (!isInitialized) {
            sleepCount++
            await sleep(200)
            if (sleepCount > 10) return
        }

        const fontBase64 = base64
        console.log(`setData is called..`)
        currentFontFamily = fontFamily
        currentFontFilename = []
        currentFontBase64 = fontBase64
        currentJson = json
        boundingBoxTexts = texts
        openTypeFont = []

        //const elements1 = document.getElementsByClassName("lottie-for-font-load-temporary-tags")
        //while (elements1.length > 0) {
        //    elements1[0].parentNode.removeChild(elements1[0])
        //}

        //const elements2 = document.getElementsByClassName("font-tags")
        //while (elements2.length > 0) {
        //    elements2[0].parentNode.removeChild(elements2[0])
        //}

        for (let i = 0; i < currentFontBase64.length; i++) {
            openTypeFont.push(opentype.parse(base64ToArrayBuffer(currentFontBase64[i])))
        }

        while (styleList.length > 0) {
            const s = styleList.pop()
            document.head.removeChild(s)
        }

        for (let i = 0; i < currentFontFamily.length; i++) {
            const styleEl = document.createElement('style')
            styleEl.className = `font-tags`
            // styleEl.innerHTML = `
            //     @font-face {
            //         font-family: ${currentFontFamily[i]};
            //         src: url("${currentFontFilename[i]}");
            //     }
            // `
            styleEl.innerHTML = `
                @font-face {
                    font-family: ${currentFontFamily[i]};
                    src: url(data:application/font-woff;charset=utf-8;base64,${currentFontBase64[i]});
                }
            `

            document.head.appendChild(styleEl)
            styleList.push(styleEl)

            const div = document.createElement('div')
            div.className = `lottie-for-font-load-temporary-tags`
            div.style.position = 'absolute'
            div.style.left = '-99999px'
            div.style.fontFamily = currentFontFamily[i]
            div.style.visibility = 'hidden'
            div.innerText = currentFontFamily[i]
            document.body.appendChild(div)

            // 최대 60초동안 로드
            for (let x = 0; x < 100; x++) {
                await sleep(100)
                console.log(currentFontFamily[i], document.fonts.check(`12px ${currentFontFamily[i]}`))
                if (document.fonts.check(`12px ${currentFontFamily[i]}`)) break
            }
        }

        const { assets, layers } = currentJson
        const textCompMap = {}

        console.log('111111111111111111111111');

        assets.forEach(item => {
            if (item.nm && typeof item.nm === 'string' && item.nm.toLowerCase().startsWith('#text')) {
                textCompMap[item.nm] = item
            }
        })
        layers.forEach(item => {
            if (item.nm && typeof item.nm == 'string' && item.nm.toLowerCase().startsWith('@preview')) {
                previewFrameNumber = parseInt(item.ip)
            }
        })

        console.log('222222222222222222222222');
        textComps = Object.keys(textCompMap)
        textComps.sort((a, b) => a > b ? 1 : a < b ? -1 : 0)
        console.log(textComps.join('\n'))
        console.log(textCompMap)

        const replaceText = (layers, text) => {
            let originalText = ''
            if (!text) text = ''

            for (let i = 0; i < layers.length; i++) {
                const layer = layers[i]
                if (layer.nm === '@Source') {
                    originalText = String(layer.t.d.k[0].s.t)
                    layer.t.d.k[0].s.t = text
                    console.log(layer)
                    break
                }
            }
            layers.forEach(layer => {
                if (layer.t &&
                    layer.t.d &&
                    layer.t.d.k &&
                    layer.t.d.k[0] &&
                    layer.t.d.k[0].s &&
                    layer.t.d.k[0].s.t &&
                    layer.t.d.k[0].s.t === originalText
                ) {
                    layer.t.d.k[0].s.t = text
                }
            })
        }
        textComps.forEach((name, index) => {
            replaceText(textCompMap[name].layers, texts[index])
        })
    }

    let isInitialized = false
    window.addEventListener("flutterInAppWebViewPlatformReady", function (event) {
        console.log('flutter webview initialized!')
        isInitialized = true

        if (window.flutter_inappwebview) {
            window.flutter_inappwebview.callHandler('TransferInit')
        }
    })

    async function extractPreview() {
        if (!isInitialized) return

        const images = document.getElementsByTagName('img');
        while(images.length > 0) {
            images[0].parentNode.removeChild(images[0]);
        }

        // setData({
        //     fontFamily: loadedFontFamily,
        //     fontFilename: loadedFontFilename,
        //     fontBase64: loadedFontBase64,
        //     json: loadedJson,
        //     texts: [ 'THIS IS VIMON', 'FANCY-TITLE!!' ]
        // })
        runPreview()
    }

    async function extractAllSequence() {
        if (!isInitialized) return

        const images = document.getElementsByTagName('img');
        while(images.length > 0) {
            images[0].parentNode.removeChild(images[0]);
        }

        // setData({
        //     fontFamily: loadedFontFamily,
        //     fontFilename: loadedFontFilename,
        //     fontBase64: loadedFontBase64,
        //     json: loadedJson,
        //     texts: [ 'THIS IS VIMON', 'FANCY-TITLE!!' ]
        // })
        runAll()
    }

    const AssignFrameNumber = (node, index) => {
        if (node.attributes) {
            for (let i = 0; i < node.attributes.length; i++) {
                const attribute = node.attributes[i]
                attribute.value = attribute.value.replace(/__lottie_element/gi, `__lottie_element_frame_${index}`)
            }
        }
        for (let i = 0; i < node.childNodes.length; i++) {
            AssignFrameNumber(node.childNodes[i], index)
        }
        return node
    }

    const ResetUnusedDefs = defsNode => {
        if (defsNode.hasChildNodes()) {
            defsNode.childNodes.forEach(childNode => {
                if (childNode.tagName === 'filter' && childNode.getAttribute('filterUnits') === 'objectBoundingBox') {
                    childNode.removeAttribute('x')
                    childNode.removeAttribute('y')
                    childNode.removeAttribute('width')
                    childNode.removeAttribute('height')
                }
                else if (childNode.tagName === 'text') {
                    childNode.remove()
                }
            })
        }
    }

    const convertTextToPath = (node, textElements = []) => {
        const findParent = node => {
            if (node.hasAttribute('font-family')) return node
            else if (node.parentNode) {
                return findParent(node.parentNode)
            }
        }
        const findTextValue = node => {
            if (node.hasChildNodes()) {
                let value = ''
                node.childNodes.forEach(childNode => {
                    if (!value) {
                        value = findTextValue(childNode)
                    }
                })
                return value
            }
            else return node.innerHTML ? node.innerHTML : node.nodeValue
        }
        if (node.tagName === 'text') {
            const parent = findParent(node)
            if (!parent) return

            const value = findTextValue(node) || ''
            const textAnchor = node.getAttribute("text-anchor")
            const fill = parent.getAttribute("fill")
            const fontSize = Number(parent.getAttribute("font-size"))
            const fontFamily = parent.getAttribute('font-family')
            let OTF = openTypeFont[0]
            let path = OTF.getPath(value, 0, 0, fontSize)

            for (let i = 0; i < currentFontFamily.length; i++) {
                if (currentFontFamily[i] === fontFamily) {
                    OTF = openTypeFont[i]
                    path = OTF.getPath(value, 0, 0, fontSize)
                    break
                }
            }

            if (textAnchor) {
                const { x1, x2 } = path.getBoundingBox()
                const width = x2 - x1

                let calculatedX = 0

                switch (textAnchor) {
                    case 'middle':
                        calculatedX -= (width / 2)
                        break

                    case 'end':
                        calculatedX -= width
                        break

                    case 'start':
                    default:
                        break
                }
                path = OTF.getPath(value, calculatedX, 0, fontSize)
            }

            const pathElement = path.toDOMElement()
            if (node.attributes) {
                for (let i = 0; i < node.attributes.length; i++) {
                    const attribute = node.attributes[i]
                    pathElement.setAttribute(attribute.name, attribute.value)
                }
            }
            pathElement.setAttribute("fill", fill)
            node.parentNode.appendChild(pathElement)
            textElements.push(node)
        }
        else if (node.hasChildNodes()) {
            node.childNodes.forEach(node => {
                convertTextToPath(node, textElements)
            })
        }
        return textElements
    }

    function DrawPNG(svgElement, anim, x, y, idx, isPreview) {
        return new Promise((resolve, reject) => {
            const image = new Image()
            const src = 'data:image/svg+xml,' + encodeURIComponent((new XMLSerializer).serializeToString(svgElement))
            image.onload = function (e) {
                const canvas = document.createElement('canvas')
                const ctx = canvas.getContext('2d')
                canvas.width = gWidth
                canvas.height = gHeight

                ctx.drawImage(image, x - 15, y - 15, gWidth, gHeight, 0, 0, gWidth, gHeight)

                if (isPreview && previewData && previewData.data && previewData.data.length > 0) {
                    textData = []
                    previewData.data.forEach(function (item, index) {
                        const rectX = (previewData.data[index].rect.x - gridData.x)
                        const rectY = (previewData.data[index].rect.top - gridData.y)
                        const rectWidth = previewData.data[index].rect.width + 45
                        const rectHeight = previewData.data[index].rect.height + 30
                        textData.push({
                            key: item.key,
                            value: boundingBoxTexts[index] || '',
                            x: rectX,
                            y: rectY,
                            width: rectWidth,
                            height: rectHeight
                        })
                        // ctx.globalAlpha = 0.2
                        // ctx.fillRect(rectX, rectY, rectWidth, rectHeight)
                    })
                }

                resolve(canvas.toDataURL('image/png'))
            }
            image.onerror = function (e) {
                reject(e)
            }
            image.src = src
        })
    }

    let isRunning = false

  setNodeMaskClipPath = (node, isText) => {
    if (!node.nodeValue) {
      const id = node.getAttribute('id')
      if (!isText && id && id.toLowerCase().startsWith('text')) {
          isText = true
      }
      if (isText) {
        if (node.getAttribute('clip-path')) {
            node.setAttribute('clip-path', '')
        }
        if (node.getAttribute('mask')) {
            node.setAttribute('mask', '')
        }
      }
    //   console.log(`isText : ${isText}, id : ${id}`);
    }

    if (node.hasChildNodes()) {
      node.childNodes.forEach(childNode => {
        setNodeMaskClipPath(childNode, isText)
      })
    }
  }

    async function runPreview() {
        if (isRunning) return
        if (!isInitialized) return

        previewData = {}
        gridData = {}
        prevTime = 0
        gWidth = 0
        gHeight = 0
        textData = []

        if (anim) {
            anim.destroy()
        }

        anim = bodymovin.loadAnimation({
            container: document.getElementById('bodymovin'),
            renderer: 'svg',
            loop: false,
            autoplay: false,
            animationData: currentJson
        })

        let currentFrame = 0
        anim.addEventListener('DOMLoaded', async function (e) {
            try {
                const list = []
                const now = Date.now()

                bodymovin.goToAndStop(previewFrameNumber, true)

                const rootSVGElement = anim.renderer.svgElement.cloneNode(false)
                rootSVGElement.style.width = ''
                rootSVGElement.style.height = ''

                anim.renderer.svgElement.childNodes.forEach(node => {
                    switch (node.tagName) {
                        case 'defs': {
                            const defsEl = AssignFrameNumber(node.cloneNode(true), previewFrameNumber)
                            ResetUnusedDefs(defsEl)
                            rootSVGElement.appendChild(defsEl)
                        }
                            break

                        case 'g': {
                            setNodeMaskClipPath(node, false)

                            const gEl = node.cloneNode(true)
                            const textElements = convertTextToPath(gEl)
                            textElements.forEach(element => element.remove())

                            gElement = gEl
                            rootSVGElement.appendChild(AssignFrameNumber(gEl, previewFrameNumber))
                        }
                            break
                    }
                })
                if (gElement) {
                    const tempsvg = document.body.querySelector('#tempsvg')
                    tempsvg.appendChild(rootSVGElement)

                    if (gElement.getBBox().width + 30 > gWidth) {
                        gWidth = gElement.getBBox().width + 30
                        gridData.x = gElement.getBoundingClientRect().x
                        gridData.width = gWidth
                        svgX = rootSVGElement.getBoundingClientRect().x
                    }
                    if (gElement.getBBox().height + 30 > gHeight) {
                        gHeight = gElement.getBBox().height + 30
                        gridData.y = gElement.getBoundingClientRect().y
                        gridData.height = gHeight
                        svgY = rootSVGElement.getBoundingClientRect().y
                    }

                    // PREVIEW의 데이터 뽑기
                    previewData["gElement"] = gElement.getBoundingClientRect()
                    previewData["data"] = []
                    textComps.forEach((name, index) => {
                        const TEXTBOX = rootSVGElement.querySelector(`g#${name.replace("#", "")}`)
                        const rect = {}
                        rect.x = TEXTBOX.getBBox().x
                        rect.y = TEXTBOX.getBBox().y
                        rect.width = TEXTBOX.getBBox().width
                        rect.height = TEXTBOX.getBBox().height
                        rect.top = TEXTBOX.getBoundingClientRect().top
                        rect.left = TEXTBOX.getBoundingClientRect().left

                        if (TEXTBOX) {
                            previewData["data"].push({ key: name, rect: rect })
                        }
                    })
                    tempsvg.removeChild(rootSVGElement)
                }
                list.push(rootSVGElement)

                const results = await Promise.all(list.map((svg, idx) => DrawPNG(svg, anim, gridData.x - svgX, gridData.y - svgY, idx, true)))

                // for (const idx in results) {
                //     const image = new Image()
                //     image.src = results[idx]
                //     document.body.appendChild(image)
                // }

                // console.log(`To Flutter Preview data : `)
                // console.dir({
                //     width: gWidth,
                //     height: gHeight,
                //     frameRate: anim.animationData.fr,
                //     preview: results[0],
                //     textData
                // })

                if (window.flutter_inappwebview) {
                    window.flutter_inappwebview.callHandler('TransferPreviewPNGData', {
                        width: gWidth,//anim.animationData.w,
                        height: gHeight,//anim.animationData.h,
                        frameRate: anim.animationData.fr,
                        preview: results[0],
                        textData
                    })
                }
                //bodymovin.destroy()
                console.log(`elapsed - : ${Date.now() - now}ms`)
            }
            catch (e) {
                console.log(String(e))
                bodymovin.destroy()
                isRunning = false

                if (window.flutter_inappwebview) {
                    window.flutter_inappwebview.callHandler('TransferPreviewFailed')
                }
            }
        })
    }

    async function runAll() {
        if (isRunning) return
        if (!isInitialized) return

        previewData = {}
        gridData = {}
        prevTime = 0
        gWidth = 0
        gHeight = 0
        textData = []

        if (anim) {
            anim.destroy()
        }

        anim = bodymovin.loadAnimation({
            container: document.getElementById('bodymovin'),
            renderer: 'svg',
            loop: false,
            autoplay: false,
            animationData: currentJson
        })

        let currentFrame = 0
        anim.addEventListener('DOMLoaded', async function (e) {
            try {
                const list = []
                const now = Date.now()

                for (let i = 0; i < anim.totalFrames; i++) {
                    bodymovin.goToAndStop(i, true)

                    const rootSVGElement = anim.renderer.svgElement.cloneNode(false)
                    rootSVGElement.style.width = ''
                    rootSVGElement.style.height = ''

                    anim.renderer.svgElement.childNodes.forEach(node => {
                        switch (node.tagName) {
                            case 'defs': {
                                const defsEl = AssignFrameNumber(node.cloneNode(true), i)
                                ResetUnusedDefs(defsEl)
                                rootSVGElement.appendChild(defsEl)
                            }
                            break

                            case 'g': {
                                setNodeMaskClipPath(node, false)

                                const gEl = node.cloneNode(true)
                                const textElements = convertTextToPath(gEl)
                                textElements.forEach(element => element.remove())

                                gElement = gEl
                                rootSVGElement.appendChild(AssignFrameNumber(gEl, i))
                            }
                            break
                        }
                    })
                    if (gElement) {
                        const tempsvg = document.body.querySelector('#tempsvg')
                        tempsvg.appendChild(rootSVGElement)

                        if (gElement.getBBox().width + 30 > gWidth) {
                            gWidth = gElement.getBBox().width + 30
                            gridData.x = gElement.getBoundingClientRect().x
                            gridData.width = gWidth
                            svgX = rootSVGElement.getBoundingClientRect().x
                        }
                        if (gElement.getBBox().height + 30 > gHeight) {
                            gHeight = gElement.getBBox().height + 30
                            gridData.y = gElement.getBoundingClientRect().y
                            gridData.height = gHeight
                            svgY = rootSVGElement.getBoundingClientRect().y
                        }

                        // PREVIEW의 데이터 뽑기
                        if (i === previewFrameNumber) {
                            previewData["gElement"] = gElement.getBoundingClientRect()
                            previewData["data"] = []
                            textComps.forEach((name, index) => {
                                const TEXTBOX = rootSVGElement.querySelector(`g#${name.replace("#", "")}`)
                                const rect = {}
                                rect.x = TEXTBOX.getBBox().x
                                rect.y = TEXTBOX.getBBox().y
                                rect.width = TEXTBOX.getBBox().width
                                rect.height = TEXTBOX.getBBox().height
                                rect.top = TEXTBOX.getBoundingClientRect().top
                                rect.left = TEXTBOX.getBoundingClientRect().left

                                if (TEXTBOX) {
                                    previewData["data"].push({ key: name, rect: rect })
                                }
                            })
                        }
                        tempsvg.removeChild(rootSVGElement)
                    }
                    list.push(rootSVGElement)
                }

                const results = await Promise.all(list.map((svg, idx) => DrawPNG(svg, anim, gridData.x - svgX, gridData.y - svgY, idx, false)))

                // for (const idx in results) {
                //     const image = new Image()
                //     image.src = results[idx]
                //     document.body.appendChild(image)
                // }

                // console.log(`To Flutter All Sequence data : `)
                // console.dir({
                //     width: gWidth,
                //     height: gHeight,
                //     frameRate: anim.animationData.fr,
                //     frames: results
                // })

                if (window.flutter_inappwebview) {
                    window.flutter_inappwebview.callHandler('TransferAllSequencePNGData', {
                        width: gWidth,//anim.animationData.w,
                        height: gHeight,//anim.animationData.h,
                        frameRate: anim.animationData.fr,
                        frames: results,
                    })
                }
                //bodymovin.destroy()
                console.log(`elapsed - : ${Date.now() - now}ms`)
            }
            catch (e) {
                console.log(String(e))
                bodymovin.destroy()
                isRunning = false

                if (window.flutter_inappwebview) {
                    window.flutter_inappwebview.callHandler('TransferAllSequenceFailed')
                }
            }
        })
    }