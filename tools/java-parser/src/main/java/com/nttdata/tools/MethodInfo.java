package com.nttdata.tools;

/**
 * Representa la información de un método Java extraído por el parser.
 */
public class MethodInfo {
    private final String className;
    private final String methodSignature;
    private final String contentHash;

    public MethodInfo(String className, String methodSignature, String contentHash) {
        this.className = className;
        this.methodSignature = methodSignature;
        this.contentHash = contentHash;
    }

    public String getClassName() {
        return className;
    }

    public String getMethodSignature() {
        return methodSignature;
    }

    public String getContentHash() {
        return contentHash;
    }

    @Override
    public String toString() {
        return String.format("MethodInfo{className='%s', methodSignature='%s', contentHash='%s'}",
                className, methodSignature, contentHash);
    }
}
