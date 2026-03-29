#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' 

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}           Auto File Manager          ${NC}"
echo -e "${GREEN}======================================${NC}"

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
else
    echo -e "${RED}Not Support${NC}"
    exit 1
fi

echo -e "${YELLOW}Os: $OS${NC}"

if command -v node &> /dev/null; then
    NODE_VERSION=$(node -v)
    echo -e "${YELLOW}Node.js installed: $NODE_VERSION${NC}"
    
    if [[ $NODE_VERSION == "v22."* ]]; then
        echo -e "${GREEN}Node.js v22 installed. Skip.${NC}"
        INSTALL_NODE=false
    else
        echo -e "${YELLOW}Not Nodejs v22 reinstaling...${NC}"
        INSTALL_NODE=true
    fi
else
    echo -e "${YELLOW}Node.js Not Found.${NC}"
    INSTALL_NODE=true
fi

if [ "$INSTALL_NODE" = true ]; then
    echo -e "${YELLOW}installing Node.js v22...${NC}"
    
    if [ "$OS" = "linux" ]; then
        curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
        sudo apt-get install -y nodejs
    elif [ "$OS" = "macos" ]; then
        if ! command -v brew &> /dev/null; then
            echo -e "${RED}Homebrew Not Found:${NC}"
            echo '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
            exit 1
        fi
        brew install node@22
        brew link --overwrite node@22
    fi
    
    if command -v node &> /dev/null; then
        echo -e "${GREEN}Node.js installed: $(node -v)${NC}"
    else
        echo -e "${RED}Failed${NC}"
        exit 1
    fi
fi

if command -v npm &> /dev/null; then
    echo -e "${GREEN}npm is installed: $(npm -v)${NC}"
else
    echo -e "${RED}npm is Not found.${NC}"
    exit 1
fi

echo -e "${YELLOW}Installing dependencies${NC}"
npm install express multer ejs

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Dependensi Sucess installed${NC}"
else
    echo -e "${RED}Failed${NC}"
    exit 1
fi

echo -e "${YELLOW}Creating${NC}"
cat > index.js << 'EOF'
const express = require('express');
const path = require('path');
const fs = require('fs');
const multer = require('multer');
const app = express();
const PORT = 3000;

const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        cb(null, './');
    },
    filename: function (req, file, cb) {
        cb(null, file.originalname);
    }
});

const upload = multer({ storage: storage });

app.use(express.urlencoded({ extended: true }));
app.use(express.json());

app.set('view engine', 'ejs');

app.get('/', (req, res) => {
    const currentPath = req.query.path || './';
    const fullPath = path.resolve(currentPath);
    
    fs.readdir(fullPath, { withFileTypes: true }, (err, items) => {
        if (err) {
            return res.status(500).send('Error reading directory');
        }
        
        const files = [];
        const folders = [];
        
        items.forEach(item => {
            const itemPath = path.join(fullPath, item.name);
            const relativePath = path.relative('./', itemPath);
            
            if (item.isDirectory()) {
                folders.push({
                    name: item.name,
                    path: relativePath,
                    type: 'folder'
                });
            } else {
                files.push({
                    name: item.name,
                    path: relativePath,
                    type: 'file'
                });
            }
        });
        
        const allItems = [...folders, ...files];
        
        res.render('index', {
            currentPath: currentPath,
            items: allItems,
            parentPath: currentPath !== './' ? path.dirname(currentPath) : null
        });
    });
});

app.get('/download', (req, res) => {
    const filePath = req.query.path;
    
    if (!filePath) {
        return res.status(400).send('File path is required');
    }
    
    const fullPath = path.resolve(filePath);
    
    if (!fs.existsSync(fullPath)) {
        return res.status(404).send('File not found');
    }
    
    const stats = fs.statSync(fullPath);
    if (stats.isDirectory()) {
        return res.status(400).send('Cannot download a folder');
    }
    
    res.download(fullPath, path.basename(fullPath), (err) => {
        if (err) {
            console.error('Download error:', err);
            res.status(500).send('Error downloading file');
        }
    });
});

app.post('/upload', upload.single('file'), (req, res) => {
    const uploadPath = req.body.path || './';
    
    if (!req.file) {
        return res.status(400).send('No file uploaded');
    }
    
    if (uploadPath !== './') {
        const targetPath = path.join(uploadPath, req.file.filename);
        const oldPath = path.join('./', req.file.filename);
        
        fs.rename(oldPath, targetPath, (err) => {
            if (err) {
                console.error('Move file error:', err);
                return res.status(500).send('Error moving file');
            }
            res.redirect(`/?path=${encodeURIComponent(uploadPath)}`);
        });
    } else {
        res.redirect('/');
    }
});

app.post('/create-folder', (req, res) => {
    const folderName = req.body.folderName;
    const currentPath = req.body.currentPath || './';
    
    if (!folderName) {
        return res.status(400).send('Folder name is required');
    }
    
    const folderPath = path.join(currentPath, folderName);
    
    fs.mkdir(folderPath, { recursive: true }, (err) => {
        if (err) {
            console.error('Create folder error:', err);
            return res.status(500).send('Error creating folder');
        }
        res.redirect(`/?path=${encodeURIComponent(currentPath)}`);
    });
});

app.post('/delete', (req, res) => {
    const itemPath = req.body.path;
    const currentPath = req.body.currentPath || './';
    
    if (!itemPath) {
        return res.status(400).send('Path is required');
    }
    
    const fullPath = path.resolve(itemPath);
    const stats = fs.statSync(fullPath);
    
    if (stats.isDirectory()) {
        // Hapus folder secara rekursif
        fs.rm(fullPath, { recursive: true, force: true }, (err) => {
            if (err) {
                console.error('Delete folder error:', err);
                return res.status(500).send('Error deleting folder');
            }
            res.redirect(`/?path=${encodeURIComponent(currentPath)}`);
        });
    } else {
        fs.unlink(fullPath, (err) => {
            if (err) {
                console.error('Delete file error:', err);
                return res.status(500).send('Error deleting file');
            }
            res.redirect(`/?path=${encodeURIComponent(currentPath)}`);
        });
    }
});

if (!fs.existsSync('./views')) {
    fs.mkdirSync('./views');
}

const ejsTemplate = `
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>File Manager</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 15px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            overflow: hidden;
        }
        
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }
        
        .header h1 {
            margin-bottom: 10px;
        }
        
        .controls {
            padding: 20px;
            background: #f8f9fa;
            border-bottom: 1px solid #dee2e6;
            display: flex;
            gap: 15px;
            flex-wrap: wrap;
            align-items: flex-end;
        }
        
        .upload-form, .folder-form {
            flex: 1;
            min-width: 200px;
        }
        
        .form-group {
            margin-bottom: 10px;
        }
        
        .form-group label {
            display: block;
            margin-bottom: 5px;
            font-weight: bold;
            color: #495057;
        }
        
        .form-group input[type="file"],
        .form-group input[type="text"] {
            width: 100%;
            padding: 8px;
            border: 1px solid #ced4da;
            border-radius: 5px;
        }
        
        button {
            background: #007bff;
            color: white;
            border: none;
            padding: 8px 20px;
            border-radius: 5px;
            cursor: pointer;
            font-size: 14px;
            transition: background 0.3s;
        }
        
        button:hover {
            background: #0056b3;
        }
        
        .content {
            padding: 20px;
        }
        
        .breadcrumb {
            margin-bottom: 20px;
            padding: 10px;
            background: #e9ecef;
            border-radius: 5px;
        }
        
        .breadcrumb a {
            color: #007bff;
            text-decoration: none;
        }
        
        .breadcrumb a:hover {
            text-decoration: underline;
        }
        
        table {
            width: 100%;
            border-collapse: collapse;
        }
        
        th, td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #dee2e6;
        }
        
        th {
            background: #f8f9fa;
            font-weight: bold;
            color: #495057;
        }
        
        tr:hover {
            background: #f8f9fa;
        }
        
        .item-name {
            flex: 1;
        }
        
        .item-name a {
            text-decoration: none;
            color: #495057;
        }
        
        .item-name a:hover {
            color: #007bff;
        }
        
        .folder-icon, .file-icon {
            margin-right: 10px;
        }
        
        .folder-icon {
            color: #ffc107;
        }
        
        .file-icon {
            color: #6c757d;
        }
        
        .actions {
            display: flex;
            gap: 10px;
        }
        
        .btn-download {
            background: #28a745;
        }
        
        .btn-download:hover {
            background: #218838;
        }
        
        .btn-delete {
            background: #dc3545;
        }
        
        .btn-delete:hover {
            background: #c82333;
        }
        
        .empty-message {
            text-align: center;
            padding: 40px;
            color: #6c757d;
        }
        
        @media (max-width: 768px) {
            .controls {
                flex-direction: column;
            }
            
            .actions {
                flex-direction: column;
            }
            
            td {
                display: flex;
                flex-wrap: wrap;
                justify-content: space-between;
                align-items: center;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>File Manager</h1>
            <p>Manage your files and folders easily</p>
        </div>
        
        <div class="controls">
            <div class="upload-form">
                <form action="/upload" method="POST" enctype="multipart/form-data">
                    <div class="form-group">
                        <label>Upload</label>
                        <input type="file" name="file" required>
                    </div>
                    <input type="hidden" name="path" value="<%= currentPath %>">
                    <button type="submit">Upload</button>
                </form>
            </div>
            
            <div class="folder-form">
                <form action="/create-folder" method="POST">
                    <div class="form-group">
                        <label>New Folder</label>
                        <input type="text" name="folderName" placeholder="Folder Name" required>
                    </div>
                    <input type="hidden" name="currentPath" value="<%= currentPath %>">
                    <button type="submit">Create</button>
                </form>
            </div>
        </div>
        
        <div class="content">
            <div class="breadcrumb">
                <strong>Location: </strong>
                <a href="/?path=./">Root</a>
                <% if (currentPath !== './') { %>
                    <% const parts = currentPath.split('/').filter(p => p && p !== '.'); %>
                    <% let accumulatedPath = './'; %>
                    <% parts.forEach((part, index) => { %>
                        <% accumulatedPath = path.join(accumulatedPath, part); %>
                        <% if (index < parts.length - 1) { %>
                            > <a href="/?path=<%= accumulatedPath %>"><%= part %></a>
                        <% } else { %>
                            > <strong><%= part %></strong>
                        <% } %>
                    <% }) %>
                <% } %>
            </div>
            
            <table>
                <thead>
                    <tr>
                        <th>Nama</th>
                        <th style="width: 150px">Aksi</th>
                    </tr>
                </thead>
                <tbody>
                    <% if (parentPath) { %>
                    <tr>
                        <td>
                            <a href="/?path=<%= parentPath %>">
                                <span class="folder-icon">📁</span> ..
                            </a>
                        </td>
                        <td></td>
                    </tr>
                    <% } %>
                    
                    <% if (items.length === 0 && !parentPath) { %>
                    <tr>
                        <td colspan="2" class="empty-message">
                            Folder Empty
                        </td>
                    </tr>
                    <% } %>
                    
                    <% items.forEach(item => { %>
                    <tr>
                        <td>
                            <% if (item.type === 'folder') { %>
                                <a href="/?path=<%= item.path %>">
                                    <span class="folder-icon">📁</span> <%= item.name %>
                                </a>
                            <% } else { %>
                                <span class="file-icon">📄</span> <%= item.name %>
                            <% } %>
                        </td>
                        <td>
                            <div class="actions">
                                <% if (item.type === 'file') { %>
                                    <a href="/download?path=<%= item.path %>" class="btn-download" style="text-decoration: none; color: white; background: #28a745; padding: 5px 10px; border-radius: 3px; display: inline-block;">⬇️ Download</a>
                                <% } %>
                                <form action="/delete" method="POST" style="display: inline;">
                                    <input type="hidden" name="path" value="<%= item.path %>">
                                    <input type="hidden" name="currentPath" value="<%= currentPath %>">
                                    <button type="submit" class="btn-delete" style="background: #dc3545;" onclick="return confirm('Apakah Anda yakin ingin menghapus <%= item.name %>?')">🗑️ Delete</button>
                                </form>
                            </div>
                        </td>
                    </tr>
                    <% }) %>
                </tbody>
            </table>
        </div>
    </div>
</body>
</html>
`;

fs.writeFileSync('./views/index.ejs', ejsTemplate);
app.listen(PORT, () => {
    console.log(`Server berjalan di http://localhost:${PORT}`);
    console.log(`Folder yang di manage: ${path.resolve('./')}`);
});
EOF

fi
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}Complete. Running web...${NC}"
echo -e "${GREEN}======================================${NC}"
echo -e "${YELLOW}Server Running At http://localhost:3000${NC}"
echo ""

node server.js
