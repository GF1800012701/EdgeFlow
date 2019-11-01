package utils;

import org.apache.thrift.TException;
import servers.Server;

import java.io.*;
import java.util.*;

public class DataUtils{

    public static String dataDir;
    public static String targetDir;
    public static String sourceDir;
    public static String targetFilename;

    public static void init(Properties properties)
    {
        dataDir = (String)properties.get("dataDir");
        targetDir = (String)properties.get("targetDir");
        sourceDir = (String)properties.get("sourceDir");
        targetFilename = (String)properties.get("targetFilename");

        FileUtils.mkdir(dataDir+'/'+targetDir);
        FileUtils.mkdir(dataDir+'/'+sourceDir);
    }

    private static  List<String> fileLists;
    private static int pFile;
    public static void initFileLists()
    {
        fileLists = Arrays.asList(FileUtils.getFileList(dataDir + '/' + sourceDir));
        pFile = 0;
    }

    public static Data getTargetData()
    {
        String filedata = FileUtils.readFile(dataDir+'/'+targetDir+'/'+targetFilename);
        Data data = new Data(0, filedata, 0);
        return data;
    }

    public static String nextData(){
        if(pFile<fileLists.size())
            return fileLists.get(pFile++);
        return null;
    }

    public static class Data  implements Serializable
    {
        private int id_ED;
        private int id_AP;
        private String data;
        private double divisionPercentageAP;
        private double computeCapacityAP;

        public double getComputeCapacityAP() {
            return computeCapacityAP;
        }

        public int getId_AP() {
            return id_AP;
        }

        public void setId_AP(int id_AP) {
            this.id_AP = id_AP;
        }

        public void setComputeCapacityAP(double computeCapacityAP) {
            this.computeCapacityAP = computeCapacityAP;
        }

        public double getComputeCapacityCC() {
            return computeCapacityCC;
        }

        public void setComputeCapacityCC(double computeCapacityCC) {
            this.computeCapacityCC = computeCapacityCC;
        }

        private double computeCapacityCC;


        public Data(int id, String data, double divisionPercentageAP)
        {
            id_ED = id;
            this.data = data;
            this.divisionPercentageAP = divisionPercentageAP;
        }

        public int getId_ED() {
            return id_ED;
        }

        public String getData() {
            return data;
        }

        public double getDivisionPercentageAP() {
            return divisionPercentageAP;
        }

        public void setData(String data) {
            this.data = data;
        }
    }

    public static boolean saveData(String filename, String filedata)
    {
        try {
            FileUtils.writeFile(dataDir+targetFilename, filedata);
            return true;
        } catch (IOException e) {
            e.printStackTrace();
            return false;
        }
    }

    public static class ProcessedData implements Serializable
    {
        private int id_ED;
        private String result;

        ProcessedData(int id, String r)
        {
            id_ED = id;
            result = r;
        }

        public int getId_ED() {
            return id_ED;
        }

        public String getResult() {
            return result;
        }
    }


    public static class PutDataThread implements Runnable
    {
        DataQueue_ q;
        Data data;
        public PutDataThread(DataQueue_ dataQueue, Data a)
        {
            q = dataQueue;
            data = a;
        }

        @Override
        public void run() {
            q.put(data);
        }
    }

    public  static class ComputeThread implements Runnable
    {
        DataQueue q;
        String targetFilename;
        servers.Server server;
        public ComputeThread(servers.Server server, DataQueue dataQueue)
        {
            this.server = server;
            q = dataQueue;
            targetFilename = DataUtils.dataDir + '/' + DataUtils.targetDir + '/' + DataUtils.targetFilename;;
        }

        @Override
        public void run() {
            Data data;
            String filename;

            while(true)
            {
                data = q.get();

                // 计算任务的参数
                filename = data.getData();
                double cpulimit;
                if(server.getType() == Server.serverType.CCLayer)
                {
                    cpulimit = data.getComputeCapacityCC();
                }
                else if(server.getType() == Server.serverType.APLayer)
                {
                    cpulimit = data.getComputeCapacityAP();
                }
                else
                    cpulimit = 100;

                // 具体计算的部分
                // TODO
                // 这里把调用Python的命令行指令添加进来即可
                String cmd = String.format("cpulimit -l %f python *** ***", cpulimit);// 需要补完
                Process p = null;
                try {
                    p = SysUtils.execCmd(cmd);
                } catch (IOException e) {
                    e.printStackTrace();
                } catch (InterruptedException e) {
                    e.printStackTrace();
                }

                InputStream is = p.getInputStream();
                try {
                    p.waitFor();
                } catch (InterruptedException e) {
                    e.printStackTrace();
                }
                BufferedReader bs = new BufferedReader(new InputStreamReader(is));
                String result = null;
                try {
                    result = bs.readLine();
                } catch (IOException e) {
                    e.printStackTrace();
                }

                ProcessedData processedData = new ProcessedData(data.getId_ED(), result);
                try {
                    server.uploadFile(ObjectUtils.objectToString(processedData), data.getId_ED());
                } catch (IOException e) {
                    e.printStackTrace();
                } catch (TException e) {
                    e.printStackTrace();
                } catch (ClassNotFoundException e) {
                    e.printStackTrace();
                }
            }
        }
    }

    public  static class DataQueue_
    {
        private DataQueue q;
        public DataQueue_(DataQueue dataQueue)
        {
            q = dataQueue;
        }

        public synchronized void put(Data data)
        {
            q.put(data);
        }
    }

    public static class DataQueue
    {
        private Queue<Data> queue = new LinkedList<>();
        private boolean available = false;

        public synchronized Data get()
        {
            while(available == false)
            {
                try {
                    wait();
                } catch (InterruptedException e) {
                    e.printStackTrace();
                }
            }
            Data filename = queue.remove();
            available = false;
            notify();
            return filename;
        }

        public synchronized void put(Data data)
        {
            while(available == true)
            {
                try {
                    wait();
                } catch (InterruptedException e) {
                    e.printStackTrace();
                }
            }
            queue.add(data);
            available = true;
            notify();
        }
    }
}