package com.nttdata.tools;

import com.github.javaparser.JavaParser;
import com.github.javaparser.ParseResult;
import com.github.javaparser.ast.CompilationUnit;
import com.github.javaparser.ast.body.ClassOrInterfaceDeclaration;
import com.github.javaparser.ast.body.MethodDeclaration;
import com.github.javaparser.ast.body.Parameter;
import com.github.javaparser.ast.comments.Comment;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;

import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

/**
 * CLI para parsear archivos Java usando JavaParser (AST) y extraer información de métodos.
 * 
 * Uso: java -jar java-method-parser.jar <archivo.java>
 * 
 * Output: JSON con array de métodos extraídos
 */
public class JavaMethodParserCLI {
    
    private static final Gson GSON = new GsonBuilder().setPrettyPrinting().create();
    
    public static void main(String[] args) {
        if (args.length == 0) {
            System.err.println("ERROR: No se especificó archivo Java");
            System.err.println("Uso: java -jar java-method-parser.jar <archivo.java>");
            System.exit(1);
        }
        
        String filePath = args[0];
        File file = new File(filePath);
        
        if (!file.exists()) {
            System.err.println("ERROR: Archivo no encontrado: " + filePath);
            System.exit(1);
        }
        
        if (!file.isFile() || !file.getName().endsWith(".java")) {
            System.err.println("ERROR: El archivo debe ser un .java válido");
            System.exit(1);
        }
        
        try {
            List<MethodInfo> methods = parseJavaFile(file);
            
            // Output JSON a stdout
            System.out.println(GSON.toJson(methods));
            
        } catch (Exception e) {
            System.err.println("ERROR: " + e.getMessage());
            e.printStackTrace();
            System.exit(1);
        }
    }
    
    /**
     * Parsea un archivo Java y extrae información de todos los métodos.
     */
    private static List<MethodInfo> parseJavaFile(File file) throws IOException {
        List<MethodInfo> methods = new ArrayList<>();
        
        // Crear parser
        JavaParser javaParser = new JavaParser();
        
        // Parsear archivo
        ParseResult<CompilationUnit> parseResult = javaParser.parse(file);
        
        if (!parseResult.isSuccessful()) {
            StringBuilder errors = new StringBuilder("Errores de parseo:\n");
            parseResult.getProblems().forEach(problem -> 
                errors.append("  - ").append(problem.getMessage()).append("\n")
            );
            throw new IOException(errors.toString());
        }
        
        CompilationUnit cu = parseResult.getResult().orElseThrow(
            () -> new IOException("No se pudo obtener CompilationUnit")
        );
        
        // Obtener nombre de la clase principal
        Optional<ClassOrInterfaceDeclaration> primaryClass = cu.findFirst(
            ClassOrInterfaceDeclaration.class,
            c -> !c.isNestedType()
        );
        
        String className = primaryClass.map(c -> c.getNameAsString())
                                       .orElse("UnknownClass");
        
        // Extraer todos los métodos (incluyendo de clases anidadas)
        List<MethodDeclaration> methodDeclarations = cu.findAll(MethodDeclaration.class);
        
        for (MethodDeclaration method : methodDeclarations) {
            try {
                String signature = buildMethodSignature(method);
                String hash = calculateMethodHash(method);
                
                methods.add(new MethodInfo(className, signature, hash));
                
            } catch (Exception e) {
                System.err.println("WARN: Error procesando método " + method.getNameAsString() + 
                                   ": " + e.getMessage());
            }
        }
        
        return methods;
    }
    
    /**
     * Construye la firma del método: nombreMetodo(Tipo1,Tipo2,...)
     * Soporta sobrecarga manteniendo los tipos de parámetros.
     */
    private static String buildMethodSignature(MethodDeclaration method) {
        String methodName = method.getNameAsString();
        
        // Extraer tipos de parámetros
        List<String> paramTypes = method.getParameters().stream()
            .map(Parameter::getType)
            .map(type -> type.asString())
            .collect(Collectors.toList());
        
        String params = String.join(",", paramTypes);
        
        return methodName + "(" + params + ")";
    }
    
    /**
     * Calcula el hash SHA-256 del cuerpo del método normalizado.
     * Normalización: elimina espacios en blanco innecesarios y comentarios.
     */
    private static String calculateMethodHash(MethodDeclaration method) throws NoSuchAlgorithmException {
        // Clonar el método para no afectar el AST original
        MethodDeclaration methodCopy = method.clone();
        
        // Eliminar todos los comentarios
        methodCopy.getAllContainedComments().forEach(Comment::remove);
        methodCopy.getComment().ifPresent(Comment::remove);
        
        // Obtener código normalizado (JavaParser maneja el formato)
        String normalizedCode = methodCopy.toString();
        
        // Normalización adicional: eliminar espacios múltiples y saltos de línea excesivos
        normalizedCode = normalizedCode.replaceAll("\\s+", " ")
                                       .replaceAll("\\s*\\{\\s*", "{")
                                       .replaceAll("\\s*\\}\\s*", "}")
                                       .replaceAll("\\s*;\\s*", ";")
                                       .replaceAll("\\s*,\\s*", ",")
                                       .trim();
        
        // Calcular SHA-256
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        byte[] hashBytes = digest.digest(normalizedCode.getBytes(StandardCharsets.UTF_8));
        
        // Convertir a hexadecimal
        StringBuilder hexString = new StringBuilder();
        for (byte b : hashBytes) {
            String hex = Integer.toHexString(0xff & b);
            if (hex.length() == 1) {
                hexString.append('0');
            }
            hexString.append(hex);
        }
        
        return hexString.toString();
    }
}
