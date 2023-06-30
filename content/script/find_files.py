import os
import sys
import json
import shutil

# ========================= 从文件夹下找到目标文件targets并拷贝到一个文件夹下 ==========================
def find_files(targets, folder):
    found_files = []
    missing_files = []
    
    # 遍历目标文件夹及其子文件夹
    for root, dirs, files in os.walk(folder):
        for file_name in files:
            file_path = os.path.join(root, file_name)
            # 判断文件是否在目标列表中
            if file_name in targets:
                found_files.append(file_path)
            # else:
                # missing_files.append(file_name)

    # 打印未找到的文件
    if missing_files:
        print("以下文件未找到：")
        for file_name in missing_files:
            print(file_name)

    return found_files

def copy_files(found_files, output_folder):

    # print("found_files：", found_files)
    # print("output_folder：" + output_folder)

    # 创建目标文件夹
    output_folder = os.path.abspath("content/test/" + output_folder)
    print("output_folder1:", output_folder)

    os.makedirs(output_folder, exist_ok=True)

    if os.path.exists(output_folder):
        print("文件夹创建成功")
    else:
        print("文件夹创建失败")


    # 复制文件到目标文件夹
    for file_path in found_files:
        file_name = os.path.basename(file_path)
        destination_path = os.path.join(output_folder, file_name)
        shutil.copy2(file_path, destination_path)

    return output_folder

# ============================ 提取.m和.swift中重要部分代码 ===========================
def extract_code_from_file(file_path, output_file):
    with open(file_path, 'r') as file:
        code = file.read()

        if file_path.endswith('.m'):
            # 提取.m文件中的所有 @implementation 到 @end 之间的代码
            start_index = code.find('@implementation')
            while start_index != -1:
                end_index = code.find('@end', start_index)
                if end_index != -1:
                    extracted_code = code[start_index:end_index+4]
                    output_file.write(extracted_code)
                    output_file.write('\n\n')  # 追加两个换行符
                start_index = code.find('@implementation', end_index)

        elif file_path.endswith('.swift'):
            # 以第一个 class 作为起点，提取整个文件直到文件末尾的代码
            start_index = code.find('class ')
            if start_index != -1:
                extracted_code = code[start_index:]
                output_file.write(extracted_code)
                output_file.write('\n\n')  # 追加两个换行符

# =============================== 合并folder文件夹下所有文件到一个新的文件 =======================
def merge_code(folder, mergePath):
    output_file = open(mergePath, 'w')

    for root, _, files in os.walk(folder):
        for file in files:
            file_path = os.path.join(root, file)
            if file_path.endswith('.m') or file_path.endswith('.swift'):
                extract_code_from_file(file_path, output_file)

    output_file.close()


# ============================== 将包含文件名的字符串转换为包含.m和.swift的两个数组 =================
def filter_files(file_names):
    # 按换行拆分成数组
    file_names = file_names.split('\n')

    # 过滤保留 .m 和 .swift 后缀的文件名
    filtered_file_names = [name for name in file_names if name.endswith('.m') or name.endswith('.swift')]

    # 拆分成两个数组
    m_files = [name for name in filtered_file_names if name.endswith('.m')]
    swift_files = [name for name in filtered_file_names if name.endswith('.swift')]

    return m_files, swift_files


def main():
    # 读取命令行参数
    # targets = sys.argv[1]
    # file_names_str = sys.argv[1]
    # folder = sys.argv[2]
    file_names_str = """
MOJiAIVC.swift
MOJiAICloud.swift
MOJiAIAnswerGPTCell.swift
MOJiAIAnswerWordCell.swift
MOJiAIQuestionCell.swift
MDFavBaseVC.m
MOJiFavAlertVC.swift
MOJiFavBaseTableVC.m
MOJiSearchWordListVC.swift
MOJiWordListMsgVC.swift
MOJiQACloud.swift
MOJiQAMatchView.swift
MOJiHomeBaseVC.h
MOJiHomeBaseVC.m
MOJiHomeVC.swift
MOJiAudioHelper.m
MOJiProHomeVC.m
MOJiProProductCollectionCell.m
    """

    folder = '/Volumes/WJHD/xcode/Project/MainApp/mojidict_ios/MOJIDict/MOJIDict/Classes'

    # 调用方法进行文件过滤
    m_files, swift_files = filter_files(file_names_str)

    # 打印结果
    if not m_files and not swift_files:
        print("未找到 .m 或者 .swift 文件")
    else:
        print(".m 文件列表:")
        print(json.dumps(m_files, indent=4))

        print("\n.swift 文件列表:")
        print(json.dumps(swift_files, indent=4))

    for files in [m_files, swift_files] :
         # 解析 targets 参数为 JSON 数组
        targets = files
        print("当前数组：", files)
        # 查找文件
        found_files = find_files(targets, folder)
        print("搜索到的数组：", found_files)

        # 复制文件到指定文件夹
        output_folder = "list"
        mergePath = './content/test/merge.swift'

        if len(found_files) == 0 :
            print("没有搜索到任何文件")
            return

        if found_files[0].endswith('.m') :
            output_folder = output_folder + "-m"
            mergePath = mergePath.replace("merge", "merge-m")
        elif found_files[0].endswith('.swift') :
            output_folder = output_folder + "-swift"
            mergePath = mergePath.replace("merge", "merge-swift")

        copy_folder = copy_files(found_files, output_folder)

        # 指定要提取的文件夹
        print("要提取的文件夹:", copy_folder)

        # merge_code(copy_folder, mergePath)



# ========================= 主函数调用 =====================
if __name__ == "__main__":
    main()


#### Python脚本说明

# - 接收导出的code_review的文件名列表
# - 过滤出`.m`/`.swift`文件
# - 分别将`.m`/`.swift`文件从主项目中查找出来
# - 将查找到的文件合并到一个名为`merge-m`/`merge-swift`文件中
# - 分别将`merge-m`/`merge-swift`文件提交给ChatGPT审核


